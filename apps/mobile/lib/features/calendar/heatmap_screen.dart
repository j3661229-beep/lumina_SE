import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../core/network/api_client.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/shimmer_widgets.dart';
import '../../shared/widgets/app_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────
// Single provider — fetches ALL events (12 months) once, no month param needed.
// Month navigation is handled client-side by filtering this map.
final heatmapProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return await ApiClient.instance.get<Map<String, dynamic>>('/gmail/heatmap');
});

// ─────────────────────────────────────────────────────────────────────────────
// Stress palette — Google-quality colors
// ─────────────────────────────────────────────────────────────────────────────
const _kStress = {
  'low':      _StressStyle(DesignColor.green, Color(0x2210B981), '😌', 'Relaxed'),
  'medium':   _StressStyle(DesignColor.cyan,  Color(0x2206B6D4), '📘', 'Normal'),
  'high':     _StressStyle(DesignColor.amber, Color(0x22F59E0B), '⚡', 'Busy'),
  'critical': _StressStyle(DesignColor.rose,  Color(0x22EF4444), '🔥', 'Crunch!'),
};

class _StressStyle {
  final Color primary, soft;
  final String emoji, label;
  const _StressStyle(this.primary, this.soft, this.emoji, this.label);
}

String _fmtKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class HeatmapScreen extends ConsumerStatefulWidget {
  const HeatmapScreen({super.key});
  @override
  ConsumerState<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends ConsumerState<HeatmapScreen>
    with SingleTickerProviderStateMixin {
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  bool _syncing = false;
  bool _refreshing = false; // subtle overlay — keeps calendar visible
  String? _banner;
  bool _bannerOk = true;
  late AnimationController _shimmer;

  String get _ym => '${_focused.year}-${_focused.month.toString().padLeft(2, '0')}';

  // Filter the full 12-month heatmap to just the focused month (client-side)
  Map<String, dynamic> _filterMonth(Map<String, dynamic> full) {
    return Map.fromEntries(
      full.entries.where((e) => e.key.startsWith(_ym)),
    );
  }

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() { _shimmer.dispose(); super.dispose(); }

  // ── Gmail sync — always request fresh consent with Gmail+Calendar scopes ────
  Future<void> _syncGmail() async {
    setState(() { _syncing = true; _banner = null; });
    try {
      final client = Supabase.instance.client;

      // Always trigger fresh OAuth WITH Gmail scopes.
      // We use prompt=consent + access_type=offline to force Google to return
      // a token with the Gmail/Calendar scopes even if already signed in.
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        scopes:
            'email profile '
            'https://www.googleapis.com/auth/gmail.readonly '
            'https://www.googleapis.com/auth/calendar.readonly',
        redirectTo: 'io.supabase.lumina://login-callback/',
        queryParams: {
          'prompt': 'consent',        // forces scope consent screen
          'access_type': 'online',    // gets fresh access token
        },
      );

      // Wait for auth state change (up to 2 min)
      final completer = Completer<Session?>();
      late final StreamSubscription<AuthState> sub;
      sub = client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedIn ||
            data.event == AuthChangeEvent.tokenRefreshed) {
          if (!completer.isCompleted) completer.complete(data.session);
          sub.cancel();
        }
      });

      final session = await completer.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () { sub.cancel(); return null; },
      );

      if (session == null) {
        setState(() { _banner = 'Sign-in cancelled or timed out'; _bannerOk = false; });
        return;
      }

      final token = session.providerToken;
      if (token == null || token.isEmpty) {
        // providerToken not forwarded — show instruction
        setState(() {
          _banner = '⚠ Signed in but Gmail token not available.\n'
              'In Supabase Dashboard → Auth → Providers → Google,\n'
              'add scopes: gmail.readonly calendar.readonly';
          _bannerOk = false;
        });
        return;
      }

      await _performSync(token, session.user.email ?? '');
    } catch (e) {
      setState(() {
        _banner = 'Failed: ${e.toString().split('\n')[0]}';
        _bannerOk = false;
      });
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _performSync(String googleToken, String email) async {
    try {
      final res = await ApiClient.instance.post<Map<String, dynamic>>(
        '/gmail/sync',
        data: {'access_token': googleToken},
      );
      ref.invalidate(heatmapProvider);
      final synced = res['synced'] ?? 0;
      final found  = res['found']  ?? 0;
      final debug  = (res['debug'] as List?)?.join(' | ') ?? '';
      if (mounted) {
        setState(() {
          _banner = synced > 0
              ? '✔ Synced $synced events${email.isNotEmpty ? ' from $email' : ''}'
              : '⚠ Found $found events but saved $synced'
                '${debug.isNotEmpty ? '\n$debug' : ''}';
          _bannerOk = synced > 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _banner = 'Sync failed: ${e.toString().split('\n')[0]}';
          _bannerOk = false;
        });
      }
    }
  }

  // ── Add manual event ────────────────────────────────────────────────────────
  Future<void> _addEvent() async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEventSheet(initialDate: _selected ?? _focused),
    );
    if (result != null) {
      // Navigate to the saved event's month so user sees it immediately
      final savedDate = result['date'] as DateTime?;
      if (savedDate != null && mounted) {
        setState(() {
          _focused = DateTime(savedDate.year, savedDate.month);
          _selected = savedDate;
        });
      }
      // Refresh data with subtle overlay (keeps calendar visible)
      setState(() => _refreshing = true);
      ref.invalidate(heatmapProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event added ✔'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heatAsync = ref.watch(heatmapProvider);

    // When data is refreshing after an event is saved, dismiss the overlay
    heatAsync.whenData((_) {
      if (_refreshing) {
        // Use addPostFrameCallback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _refreshing) setState(() => _refreshing = false);
        });
      }
    });

    return Scaffold(
      backgroundColor: DesignColor.bg,
      body: heatAsync.when(
        // On FIRST load (no cached data) → show full-screen shimmer skeleton
        loading: () => const CardListShimmer(count: 8, cardHeight: 56),
        error: (_, __) => _RetryView(onRetry: () => ref.invalidate(heatmapProvider)),
        // On subsequent loads (after invalidate) → keep showing calendar with overlay
        data: (fullHeatmap) => Stack(
          children: [
            _buildBody(context, cs, isDark, DesignColor.bg, fullHeatmap),
            if (_refreshing)
              const Positioned(
                top: 0, left: 0, right: 0,
                child: LinearProgressIndicator(color: DesignColor.indigo, backgroundColor: Colors.transparent),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme cs, bool isDark,
      Color bg, Map<String, dynamic> fullHeatmap) {
    // Filter to the focused month client-side — zero network calls on navigation
    final heatmap = _filterMonth(fullHeatmap);

    final selKey = _selected != null ? _fmtKey(_selected!) : '';
    final selData = heatmap[selKey] as Map<String, dynamic>?;
    final selEvents = selData?['events'] as List<dynamic>? ?? [];
    final selLevel = selData?['level'] as String?;

    // Month summary — based on FOCUSED month, not current month
    final counts = {'low':0,'medium':0,'high':0,'critical':0};
    for (final v in heatmap.values) {
      final l = (v as Map<String,dynamic>)['level'] as String?;
      if (l != null) counts[l] = (counts[l] ?? 0) + 1;
    }
    final totalBusy = heatmap.length;
    final monthLevel = (counts['critical'] ?? 0) > 0 ? 'critical'
        : (counts['high'] ?? 0) > 2 ? 'high'
        : totalBusy > 0 ? 'medium' : 'low';
    final mStyle = _kStress[monthLevel]!;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _refreshing = true);
        ref.invalidate(heatmapProvider);
      },
      edgeOffset: 100,
      child: CustomScrollView(
        slivers: [
          // ── SliverAppBar ─────────────────────────────────────────────────
          SliverAppBar(
            pinned: true, expandedHeight: 160,
            backgroundColor: mStyle.primary,
            flexibleSpace: FlexibleSpaceBar(
              // Pass focused month so header shows correct month on navigation
              background: _AppBarBackground(
                style: mStyle,
                heatmap: heatmap,
                focusedMonth: _focused,
              ),
            ),
            actions: [
              if (_syncing)
                const Padding(padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
              else
                IconButton(
                  icon: const Icon(Icons.sync_rounded, color: Colors.white),
                  tooltip: 'Sync Gmail',
                  onPressed: _syncGmail,
                ),
              IconButton(
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                onPressed: _addEvent,
              ),
            ],
          ),

          SliverToBoxAdapter(child: Column(children: [
            // ── Sync banner ────────────────────────────────────────────────
            if (_banner != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _bannerOk ? const Color(0xFF00897B).withOpacity(0.1) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _bannerOk ? const Color(0xFF00897B) : Colors.red, width: .8),
                ),
                child: Row(children: [
                  Text(_bannerOk ? '✔' : '✖', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_banner!, style: const TextStyle(fontSize: 13))),
                  GestureDetector(onTap: () => setState(() => _banner = null),
                    child: const Icon(Icons.close, size: 16)),
                ]),
              ),

            // ── Month stress bar (for focused month) ───────────────────────
            _MonthStressBar(counts: counts, total: totalBusy, focusedMonth: _focused),

            // ── Calendar Card ──────────────────────────────────────────────
            // NOTE: heatmap passed here is the FULL 12-month map so TableCalendar
            // can colour days as the user swipes between months without re-fetching.
            _CalendarCard(
              focusedDay: _focused,
              selectedDay: _selected,
              heatmap: fullHeatmap,   // <-- full map so adjacent months colour correctly
              onDaySelected: (sel, foc) => setState(() { _selected = sel; _focused = foc; }),
              onPageChanged: (d) {
                // Only update local state — full data is already loaded, no network call
                setState(() { _focused = d; _selected = null; });
              },
            ),

            const SizedBox(height: 12),

            // ── Selected day or empty hint ─────────────────────────────────
            if (_selected != null)
              _DayPanel(date: _selected!, level: selLevel, events: selEvents)
            else if (fullHeatmap.isEmpty)
              _EmptyState(onSync: _syncGmail, onManual: _addEvent)
            else
              _MonthInsights(counts: counts, focusedMonth: _focused),

            const SizedBox(height: 80),
          ])),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppBar Gradient Background
// ─────────────────────────────────────────────────────────────────────────────
class _AppBarBackground extends StatelessWidget {
  final _StressStyle style;
  final Map<String, dynamic> heatmap;
  final DateTime focusedMonth; // correctly shows navigated month
  const _AppBarBackground({
    required this.style,
    required this.heatmap,
    required this.focusedMonth,
  });

  @override
  Widget build(BuildContext context) {
    // Use focused month (not DateTime.now()) so header updates on navigation
    final monthName = DateFormat('MMMM yyyy').format(focusedMonth);
    // Mini dots show the 7 days centred on the focused month's 'today'
    final refDay = DateTime.now();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [style.primary, Color.lerp(style.primary, Colors.black, 0.3)!],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(style.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 4),
          Text(style.label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          Text(monthName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        ])),
        // Mini heatmap dots (last 7 days relative to today)
        Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          const Text('This week', style: TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 4),
          Row(children: List.generate(7, (i) {
            final d = refDay.subtract(Duration(days: 6 - i));
            final key = _fmtKey(d);
            final data = heatmap[key] as Map<String,dynamic>?;
            final color = data != null ? (_kStress[data['level']]?.primary ?? Colors.white24)
                : Colors.white24;
            return Container(
              margin: const EdgeInsets.only(left: 3),
              width: 10, height: 10,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            );
          })),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month Stress Distribution Bar
// ─────────────────────────────────────────────────────────────────────────────
class _MonthStressBar extends StatelessWidget {
  final Map<String, int> counts;
  final int total;
  final DateTime focusedMonth;
  const _MonthStressBar({required this.counts, required this.total, required this.focusedMonth});

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    // Use actual days-in-month for the focused month
    final daysInMonth = DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Stress Distribution', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.onSurface)),
          Text('$total/$daysInMonth days', style: TextStyle(fontSize: 11, color: cs.outline)),
        ]),
        const SizedBox(height: 8),
        Container(
          height: 10,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: ['low','medium','high','critical'].map((l) {
            final c = counts[l] ?? 0;
            if (c == 0) return const SizedBox.shrink();
            final ratio = c / daysInMonth;
            return Flexible(flex: (ratio * 100).round(),
              child: Container(color: _kStress[l]!.primary));
          }).toList()),
        ),
        const SizedBox(height: 8),
        Row(children: ['low','medium','high','critical'].map((l) => Expanded(
          child: Row(children: [
            Container(width: 8, height: 8,
              decoration: BoxDecoration(color: _kStress[l]!.primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Text('${counts[l] ?? 0}', style: TextStyle(color: _kStress[l]!.primary, fontSize: 11, fontWeight: FontWeight.w700)),
            Text('d', style: TextStyle(color: cs.outline, fontSize: 10)),
          ]),
        )).toList()),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar Card
// ─────────────────────────────────────────────────────────────────────────────
class _CalendarCard extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Map<String, dynamic> heatmap;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onPageChanged;
  const _CalendarCard({
    required this.focusedDay, required this.selectedDay,
    required this.heatmap, required this.onDaySelected, required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      glass: true,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: TableCalendar(
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2027, 12, 31),
          focusedDay: focusedDay,
          selectedDayPredicate: (d) => isSameDay(d, selectedDay),
          onDaySelected: onDaySelected,
          onPageChanged: onPageChanged,
          daysOfWeekHeight: 32,
          rowHeight: 52,
          calendarBuilders: CalendarBuilders(
            dowBuilder: (ctx, day) => Center(
              child: Text(
                DateFormat.E().format(day)[0],
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: day.weekday == DateTime.sunday ? Colors.red.shade300 : cs.outline,
                ),
              ),
            ),
            defaultBuilder: (ctx, day, _) => _DayCell(day: day, heatmap: heatmap, isToday: false, isSelected: false),
            todayBuilder:   (ctx, day, _) => _DayCell(day: day, heatmap: heatmap, isToday: true,  isSelected: false),
            selectedBuilder: (ctx, day, _) => _DayCell(day: day, heatmap: heatmap, isToday: false, isSelected: true),
            outsideBuilder: (ctx, day, _) => Center(
              child: Text('${day.day}', style: TextStyle(color: cs.outline.withOpacity(0.35), fontSize: 13))),
            markerBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            leftChevronIcon: Icon(Icons.chevron_left_rounded, color: cs.onSurface),
            rightChevronIcon: Icon(Icons.chevron_right_rounded, color: cs.onSurface),
            titleTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: cs.onSurface),
            headerPadding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.onSurface.withOpacity(0.05))),
            ),
          ),
          calendarStyle: const CalendarStyle(outsideDaysVisible: false),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day Cell
// ─────────────────────────────────────────────────────────────────────────────
class _DayCell extends StatelessWidget {
  final DateTime day;
  final Map<String, dynamic> heatmap;
  final bool isToday, isSelected;
  const _DayCell({required this.day, required this.heatmap, required this.isToday, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final key = _fmtKey(day);
    final data = heatmap[key] as Map<String, dynamic>?;
    final style = data != null ? _kStress[data['level']] : null;
    final evCount = (data?['events'] as List?)?.length ?? 0;

    Color bgColor = Colors.transparent;
    Color textColor = DesignColor.text;
    Color? ringColor;

    if (isSelected) {
      bgColor = style?.primary ?? DesignColor.indigo;
      textColor = Colors.white;
    } else if (isToday) {
      ringColor = DesignColor.indigo;
      textColor = DesignColor.indigo;
      if (style != null) bgColor = style.soft;
    } else if (style != null) {
      bgColor = style.soft;
      textColor = style.primary;
    }

    final isSun = day.weekday == DateTime.sunday;
    if (!isSelected && !isToday && style == null && isSun) {
      textColor = Colors.red.shade300;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: ringColor != null ? Border.all(color: ringColor, width: 2) : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('${day.day}', style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 14, color: textColor)),
        if (evCount > 0) ...[
          const SizedBox(height: 2),
          Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(evCount.clamp(0, 3), (_) =>
              Container(margin: const EdgeInsets.symmetric(horizontal: 1),
                width: 4, height: 4,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white70 : (style?.primary ?? cs.primary),
                  shape: BoxShape.circle)))),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selected Day Panel
// ─────────────────────────────────────────────────────────────────────────────
class _DayPanel extends StatelessWidget {
  final DateTime date;
  final String? level;
  final List<dynamic> events;
  const _DayPanel({required this.date, required this.level, required this.events});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = level != null ? _kStress[level] : null;
    final color = style?.primary ?? DesignColor.muted;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      decoration: DesignStyles.glassCard(),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: style != null
                  ? [color.withOpacity(0.2), color.withOpacity(0.05)]
                  : [cs.surfaceContainerHighest.withOpacity(0.3), Colors.transparent],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Center(child: Text(style?.emoji ?? '📅', style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(DateFormat('EEEE').format(date),
                style: TextStyle(fontSize: 12, color: cs.outline, fontWeight: FontWeight.w500)),
              Text(DateFormat('MMMM d, yyyy').format(date),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ])),
            if (level != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                child: Text(level!.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
          ]),
        ),

        // Events
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Icon(Icons.check_circle_outline, size: 40, color: const Color(0xFF00897B).withOpacity(0.6)),
              const SizedBox(height: 8),
              Text('Free day! 🎉', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: 2),
              Text('No deadlines on this day', style: TextStyle(color: cs.outline, fontSize: 13)),
            ]),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final ev = events[i] as Map<String, dynamic>;
              final keywords = (ev['keywords'] as List?)?.cast<String>() ?? [];
              final source = ev['source'] as String? ?? 'manual';
              return _EventCard(ev: ev, keywords: keywords, source: source, accent: color);
            },
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event Card
// ─────────────────────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final Map<String, dynamic> ev;
  final List<String> keywords;
  final String source;
  final Color accent;
  const _EventCard({required this.ev, required this.keywords, required this.source, required this.accent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconData = source == 'gmail' ? Icons.mail_rounded
        : source == 'gcal' ? Icons.calendar_today_rounded
        : Icons.edit_rounded;
    final sourceLabel = source == 'gmail' ? 'Gmail'
        : source == 'gcal' ? 'Google Calendar' : 'Manual';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(iconData, size: 16, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ev['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.label_outline, size: 11, color: cs.outline),
            const SizedBox(width: 3),
            Text(sourceLabel, style: TextStyle(fontSize: 11, color: cs.outline)),
          ]),
          if (keywords.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, children: keywords.map((k) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(k, style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.w700)),
              )).toList()),
          ],
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month Insights (shown when no day selected but has data)
// ─────────────────────────────────────────────────────────────────────────────
class _MonthInsights extends StatelessWidget {
  final Map<String, int> counts;
  final DateTime focusedMonth;
  const _MonthInsights({required this.counts, required this.focusedMonth});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthLabel = DateFormat('MMMM').format(focusedMonth);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$monthLabel — tap a day to see events', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: cs.onSurface)),
        const SizedBox(height: 4),
        Text('Colored cells indicate stress from your calendar', style: TextStyle(color: cs.outline, fontSize: 12)),
        const SizedBox(height: 16),
        // Color legend
        ...['low','medium','high','critical'].map((l) {
          final s = _kStress[l]!;
          if ((counts[l] ?? 0) == 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(width: 12, height: 12,
                decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Text(s.label, style: TextStyle(fontWeight: FontWeight.w600, color: s.primary)),
              const Spacer(),
              Text('${counts[l]} day${(counts[l] ?? 0) != 1 ? 's' : ''}',
                style: TextStyle(color: cs.outline, fontSize: 12)),
            ]),
          );
        }),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onSync, onManual;
  const _EmptyState({required this.onSync, required this.onManual});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
      ),
      child: Column(children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.email_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        Text('Connect Google', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Lumina scans Gmail for\n"deadline", "exam", "assignment"\nand auto-colors your calendar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.outline, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 20),
        // Google-style button
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: onSync,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF3C4043),
            side: const BorderSide(color: Color(0xFFDADCE0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            elevation: 1,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Google colors G
            RichText(text: const TextSpan(
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              children: [
                TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
                TextSpan(text: 'o', style: TextStyle(color: Color(0xFFEA4335))),
                TextSpan(text: 'o', style: TextStyle(color: Color(0xFFFBBC05))),
                TextSpan(text: 'g', style: TextStyle(color: Color(0xFF4285F4))),
                TextSpan(text: 'l', style: TextStyle(color: Color(0xFF34A853))),
                TextSpan(text: 'e', style: TextStyle(color: Color(0xFFEA4335))),
              ],
            )),
            const SizedBox(width: 10),
            const Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF3C4043))),
          ]),
        )),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: onManual,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add deadline manually'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Event Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _AddEventSheet extends StatefulWidget {
  final DateTime initialDate;
  const _AddEventSheet({required this.initialDate});
  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _stress = 'medium';
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Default to the focused month's first day if focused month is in the future,
    // otherwise default to today.
    final now = DateTime.now();
    final initial = widget.initialDate;
    _date = initial.isAfter(now) ? initial : now;
  }

  @override
  void dispose() { _titleCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _kStress[_stress]!.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20, right: 20, top: 16,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: cs.outline.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        Row(children: [
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.event_rounded, color: accent, size: 20)),
          const SizedBox(width: 12),
          const Text('Add Deadline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
        const SizedBox(height: 20),

        TextField(
          controller: _titleCtrl, autofocus: true,
          decoration: InputDecoration(
            labelText: 'Title *',
            prefixIcon: const Icon(Icons.title_rounded),
            filled: true,
            fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),

        // Stress level pills
        Row(children: ['low','medium','high','critical'].map((l) {
          final s = _kStress[l]!;
          final sel = _stress == l;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() => _stress = l),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: sel ? s.primary : s.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                Text(s.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 2),
                Text(s.label[0].toUpperCase() + s.label.substring(1),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : s.primary)),
              ]),
            ),
          ));
        }).toList()),
        const SizedBox(height: 12),

        // Date picker
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context, initialDate: _date,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d != null) setState(() => _date = d);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_rounded, color: cs.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(DateFormat('EEE, MMM d yyyy').format(_date),
                style: const TextStyle(fontWeight: FontWeight.w600))),
              Icon(Icons.edit_outlined, size: 16, color: cs.outline),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _noteCtrl,
          decoration: InputDecoration(
            labelText: 'Note (optional)',
            prefixIcon: const Icon(Icons.notes_rounded),
            filled: true,
            fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(width: double.infinity, child: FilledButton(
          onPressed: _saving ? null : () async {
            if (_titleCtrl.text.trim().isEmpty) return;
            setState(() => _saving = true);
            try {
              await ApiClient.instance.post('/gmail/manual', data: {
                'title': _titleCtrl.text.trim(),
                // Use local date string to avoid timezone shifts
                'event_date': '${_date.year}-${_date.month.toString().padLeft(2,'0')}-${_date.day.toString().padLeft(2,'0')}',
                'stress_level': _stress,
                if (_noteCtrl.text.isNotEmpty) 'description': _noteCtrl.text.trim(),
              });
              // Return the saved date so the parent can navigate to it
              if (context.mounted) Navigator.pop(context, <String, dynamic>{'date': _date});
            } catch (e) {
              setState(() => _saving = false);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          child: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Save Event', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OAuth Token Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _TokenDialog extends StatelessWidget {
  const _TokenDialog();
  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController();
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Google Access Token', style: TextStyle(fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('After Google sign-in, copy the access token and paste below.',
          style: TextStyle(color: cs.outline, fontSize: 13)),
        const SizedBox(height: 14),
        TextField(controller: ctrl, maxLines: 3,
          decoration: InputDecoration(
            hintText: 'ya29.a0...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          )),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, ctrl.text.trim()),
          child: const Text('Sync')),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Retry View
// ─────────────────────────────────────────────────────────────────────────────
class _RetryView extends StatelessWidget {
  final VoidCallback onRetry;
  const _RetryView({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off_rounded, size: 56, color: cs.error),
      const SizedBox(height: 12),
      const Text('Cannot load calendar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      const SizedBox(height: 6),
      Text('Is the backend running?', style: TextStyle(color: cs.outline)),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
    ]));
  }
}



