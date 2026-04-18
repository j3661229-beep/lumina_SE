import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/design_tokens.dart';
import '../../app.dart';
import '../timetable/timetable_provider.dart';
import '../expenses/expense_provider.dart';
import '../hub/hub_provider.dart';
import '../../shared/providers/profile_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final cs = Theme.of(context).colorScheme;
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['full_name'] as String? ??
        user?.email?.split('@').first ?? 'Student';
    final firstName = name.split(' ').first;

    final slotsAsync = ref.watch(timetableProvider);
    final logsAsync = ref.watch(attendanceLogsProvider);
    final analyticsAsync = ref.watch(bunkAnalyticsProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final profileAsync = ref.watch(profileProvider);

    final now = DateTime.now();
    final todayKey = DateFormat('EEEE').format(now).toLowerCase();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Gradient App Bar ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
            systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.blurBackground, StretchMode.zoomBackground],
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppColors.indigo.withOpacity(0.35), AppColors.violet.withOpacity(0.1), Colors.transparent]
                        : [AppColors.indigo.withOpacity(0.15), AppColors.violet.withOpacity(0.05), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_greeting()}, $firstName 👋',
                                  style: TextStyle(
                                    color: cs.onSurface.withOpacity(0.6),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lumina',
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  DateFormat('EEEE, MMMM d').format(now),
                                  style: TextStyle(
                                    color: cs.onSurface.withOpacity(0.45),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )),
                            // Theme Toggle
                            _IconBtn(
                              icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                ref.read(themeProvider.notifier).state =
                                    isDark ? ThemeMode.light : ThemeMode.dark;
                              },
                            ),
                            const SizedBox(width: 8),
                            _IconBtn(
                              icon: Icons.person_outline_rounded,
                              onTap: () => context.push('/profile'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Attendance Overview + Next Class ──────────────────────
                const SizedBox(height: 20),
                Row(children: [
                  // Attendance Ring
                  Expanded(
                    flex: 5,
                    child: analyticsAsync.when(
                      loading: () => _SkeletonCard(height: 130),
                      error: (_, __) => _AttendanceRing(pct: 0, label: 'No data'),
                      data: (analytics) {
                        if (analytics.isEmpty) return _AttendanceRing(pct: 0, label: 'No classes');
                        
                        final items = analytics.map((e) => e as Map<String, dynamic>).toList();
                        final avg = items.map((e) => (e['percentage'] as num?)?.toDouble() ?? 0.0)
                            .reduce((a, b) => a + b) / items.length;
                            
                        return _AttendanceRing(pct: avg / 100, label: '${avg.round()}%');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Next Class
                  Expanded(
                    flex: 7,
                    child: slotsAsync.when(
                      loading: () => _SkeletonCard(height: 130),
                      error: (_, __) => const SizedBox(),
                      data: (slots) {
                        final todaySlots = slots.where((s) =>
                          (s['day_of_week'] as String?) == todayKey).toList()
                          ..sort((a, b) => (a['start_time'] as String? ?? '').compareTo(b['start_time'] as String? ?? ''));
                        final upcoming = todaySlots.firstWhere(
                          (s) {
                            try {
                              final tp = (s['start_time'] as String?)?.split(':') ?? [];
                              if (tp.length < 2) return false;
                              final slotTime = DateTime(now.year, now.month, now.day,
                                  int.parse(tp[0]), int.parse(tp[1]));
                              return slotTime.isAfter(now);
                            } catch (_) { return false; }
                          },
                          orElse: () => {},
                        );
                        return _NextClassCard(slot: upcoming.isEmpty ? null : upcoming);
                      },
                    ),
                  ),
                ]),

                // ── Quick Actions ─────────────────────────────────────────
                const SizedBox(height: 20),
                Text('Quick Actions', style: TextStyle(
                  fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 15,
                  color: cs.onSurface)),
                const SizedBox(height: 12),
                Row(children: [
                  _QuickAction(icon: Icons.document_scanner_outlined, label: 'Scan\nTimetable',
                    color: AppColors.indigo, onTap: () => context.push('/ocr')),
                  const SizedBox(width: 10),
                  _QuickAction(icon: Icons.add_card_outlined, label: 'Add\nExpense',
                    color: AppColors.green, onTap: () => context.go('/expenses')),
                  const SizedBox(width: 10),
                  _QuickAction(icon: Icons.psychology_outlined, label: 'Ask\nLumina',
                    color: AppColors.violet, onTap: () => context.go('/rag')),
                  const SizedBox(width: 10),
                  _QuickAction(icon: Icons.analytics_outlined, label: 'Bunk\nStats',
                    color: AppColors.amber, onTap: () => context.push('/bunk')),
                ]),

                // ── Today's Schedule ──────────────────────────────────────
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("Today's Classes", style: TextStyle(
                    fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 15,
                    color: cs.onSurface)),
                  GestureDetector(
                    onTap: () => context.go('/home'),
                    child: Text('View all →', style: TextStyle(
                      color: AppColors.indigo, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 12),
                slotsAsync.when(
                  loading: () => Column(children: List.generate(2, (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SkeletonCard(height: 72)))),
                  error: (_, __) => _EmptySection(
                    icon: Icons.wifi_off_outlined, label: 'Could not load schedule'),
                  data: (slots) {
                    final todaySlots = slots.where((s) =>
                      (s['day_of_week'] as String?) == todayKey).toList()
                      ..sort((a, b) => (a['start_time'] as String? ?? '').compareTo(b['start_time'] as String? ?? ''));
                    if (todaySlots.isEmpty) return _EmptySection(
                      icon: Icons.free_breakfast_outlined, label: 'No classes today 🎉');
                    final logs = logsAsync.value ?? {};
                    return Column(
                      children: todaySlots.take(4).map((slot) =>
                        _TodayClassTile(slot: slot, markedStatus: logs['${slot['id']}_$todayStr'])).toList(),
                    );
                  },
                ),

                // ── Expense Summary ───────────────────────────────────────
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Finance Snapshot', style: TextStyle(
                    fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 15,
                    color: cs.onSurface)),
                  GestureDetector(
                    onTap: () => context.go('/expenses'),
                    child: Text('Details →', style: TextStyle(
                      color: AppColors.indigo, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 12),
                expensesAsync.when(
                  loading: () => _SkeletonCard(height: 90),
                  error: (_, __) => _EmptySection(icon: Icons.error_outline, label: 'No data'),
                  data: (expenses) {
                    final thisWeek = expenses.where((e) {
                      final d = DateTime.tryParse(e['date'] as String? ?? '');
                      if (d == null) return false;
                      return now.difference(d).inDays < 7;
                    });
                    double total = 0;
                    for (final e in thisWeek) {
                      final v = e['amount'];
                      total += v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
                    }
                    
                    final profile = profileAsync.value;
                    final budget = (profile?['weeklyBudget'] as num?)?.toDouble() ?? 2000.0;
                    
                    return _ExpenseSnapshot(weekTotal: total, itemCount: thisWeek.length, budget: budget);
                  },
                ),

                // ── Study Groups ──────────────────────────────────────────
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Study Squads', style: TextStyle(
                    fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 15,
                    color: cs.onSurface)),
                  GestureDetector(
                    onTap: () => context.go('/groups'),
                    child: Text('See all →', style: TextStyle(
                      color: AppColors.indigo, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 12),
                groupsAsync.when(
                  loading: () => _SkeletonCard(height: 70),
                  error: (_, __) => _EmptySection(icon: Icons.people_outline, label: 'No squads found'),
                  data: (groups) {
                    if (groups.isEmpty) return _GroupsTeaser();
                    return _GroupsTeaser(group: groups.first);
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── UI Widgets ────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: cs.onSurface.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.onSurface.withOpacity(0.1)),
        ),
        child: Icon(icon, color: cs.onSurface.withOpacity(0.7), size: 20),
      ),
    );
  }
}

class _AttendanceRing extends StatelessWidget {
  final double pct;
  final String label;
  const _AttendanceRing({required this.pct, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = pct >= 0.75 ? AppColors.green : pct >= 0.6 ? AppColors.amber : AppColors.rose;
    return Container(
      height: 130,
      decoration: DesignStyles.card(context),
      child: Center(
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 80, height: 80,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 8,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(
              fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 18, color: color)),
            Text('Attendance', style: TextStyle(
              fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

class _NextClassCard extends StatelessWidget {
  final Map? slot;
  const _NextClassCard({this.slot});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (slot == null) {
      return Container(
        height: 130,
        decoration: DesignStyles.card(context),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.free_breakfast_outlined, color: cs.onSurface.withOpacity(0.3), size: 28),
          const SizedBox(height: 8),
          Text('No more classes\ntoday', textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withOpacity(0.45), fontSize: 12, height: 1.4)),
        ])),
      );
    }
    final subject = slot!['subject'] as Map? ?? {};
    final name = subject['name'] as String? ?? 'Class';
    final start = slot!['start_time'] as String? ?? '';
    final type = slot!['slot_type'] as String? ?? 'lecture';
    final color = type == 'lab' ? AppColors.cyan : AppColors.indigo;

    return Container(
      height: 130,
      padding: const EdgeInsets.all(14),
      decoration: DesignStyles.card(context).copyWith(
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Next', style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ]),
        const Spacer(),
        Text(name, style: TextStyle(
          fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 14,
          color: cs.onSurface), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.access_time_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(start, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(type, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700))),
        ]),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700, height: 1.3)),
        ]),
      ),
    ));
  }
}

class _TodayClassTile extends StatelessWidget {
  final Map slot;
  final String? markedStatus;
  const _TodayClassTile({required this.slot, this.markedStatus});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subject = slot['subject'] as Map? ?? {};
    final name = subject['name'] as String? ?? 'Unknown';
    final start = slot['start_time'] as String? ?? '';
    final end = slot['end_time'] as String? ?? '';
    final type = slot['slot_type'] as String? ?? 'lecture';
    final colorHex = subject['color_hex'] as String? ?? '#6366F1';
    Color c = AppColors.indigo;
    try { c = Color(int.parse(colorHex.replaceFirst('#', 'FF'), radix: 16)); } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: DesignStyles.card(context, radius: 14).copyWith(
        border: Border(left: BorderSide(color: c, width: 3)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: 13, color: cs.onSurface, fontFamily: 'Syne')),
          const SizedBox(height: 2),
          Text('$start – $end · ${type[0].toUpperCase()}${type.substring(1)}',
            style: TextStyle(color: cs.onSurface.withOpacity(0.45), fontSize: 11)),
        ])),
        if (markedStatus != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (markedStatus == 'present' ? AppColors.green : AppColors.rose).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(markedStatus == 'present' ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 12, color: markedStatus == 'present' ? AppColors.green : AppColors.rose),
              const SizedBox(width: 4),
              Text(markedStatus == 'present' ? 'Present' : 'Absent',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: markedStatus == 'present' ? AppColors.green : AppColors.rose)),
            ]),
          )
        else
          Icon(Icons.chevron_right_rounded, color: cs.onSurface.withOpacity(0.3), size: 20),
      ]),
    );
  }
}

class _ExpenseSnapshot extends StatelessWidget {
  final double weekTotal;
  final int itemCount;
  final double budget;
  const _ExpenseSnapshot({required this.weekTotal, required this.itemCount, required this.budget});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = budget > 0 ? (weekTotal / budget).clamp(0.0, 1.0) : 0.0;
    final color = pct < 0.6 ? AppColors.green : pct < 0.85 ? AppColors.amber : AppColors.rose;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: DesignStyles.card(context),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('This Week', style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 4),
          Text('₹${weekTotal.toStringAsFixed(0)}',
            style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 24, color: color)),
          Text('$itemCount transactions', style: TextStyle(color: cs.onSurface.withOpacity(0.4), fontSize: 11)),
        ])),
        const SizedBox(width: 16),
        SizedBox(
          width: 60, height: 60,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: pct, strokeWidth: 6,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
            Text('${(pct * 100).round()}%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      ]),
    );
  }
}

class _GroupsTeaser extends StatelessWidget {
  final Map<String, dynamic>? group;
  const _GroupsTeaser({this.group});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = group?['name'] ?? 'Study Squads';
    final desc = group?['description'] ?? 'Collaborate with classmates';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: DesignStyles.card(context),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.violet.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.people_outline_rounded, color: AppColors.violet, size: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(
            fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 14, color: cs.onSurface)),
          Text(desc, style: TextStyle(
            color: cs.onSurface.withOpacity(0.5), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        GestureDetector(
          onTap: () => context.go('/groups'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.indigo, AppColors.violet]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Open', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: DesignStyles.card(context),
  );
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptySection({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: DesignStyles.card(context),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: cs.onSurface.withOpacity(0.3)),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: cs.onSurface.withOpacity(0.45), fontSize: 13)),
      ]),
    );
  }
}
