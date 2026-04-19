import 'dart:math' as math;
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _heroCtrl;
  late AnimationController _cardsCtrl;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _cardsFade;
  late Animation<Offset> _cardsSlide;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Still up? 🌙';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _cardsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _heroFade  = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(begin: const Offset(0, -0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));
    _cardsFade  = CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOut);
    _cardsSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOutCubic));
    _heroCtrl.forward();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _cardsCtrl.forward();
    });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _cardsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final cs = Theme.of(context).colorScheme;
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['full_name'] as String? ??
        user?.email?.split('@').first ?? 'Student';
    final firstName = name.split(' ').first;

    final slotsAsync    = ref.watch(timetableProvider);
    final logsAsync     = ref.watch(attendanceLogsProvider);
    final analyticsAsync= ref.watch(bunkAnalyticsProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final groupsAsync   = ref.watch(groupsProvider);
    final profileAsync  = ref.watch(profileProvider);

    final now      = DateTime.now();
    final todayKey = DateFormat('EEEE').format(now).toLowerCase();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF1F5F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── HERO APP BAR ───────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            stretch: true,
            elevation: 0,
            backgroundColor: isDark ? AppColors.darkBg : const Color(0xFF6366F1),
            systemOverlayStyle: SystemUiOverlayStyle.light,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [StretchMode.zoomBackground],
              background: _HeroHeader(
                greeting: _greeting(),
                firstName: firstName,
                now: now,
                isDark: isDark,
                fadeAnim: _heroFade,
                slideAnim: _heroSlide,
                onThemeToggle: () {
                  HapticFeedback.selectionClick();
                  ref.read(themeProvider.notifier).state =
                      isDark ? ThemeMode.light : ThemeMode.dark;
                },
                onProfile: () => context.push('/profile'),
                analyticsAsync: analyticsAsync,
              ),
            ),
            // collapsed app bar tint
            title: FadeTransition(
              opacity: ReverseAnimation(_heroFade),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.indigo, AppColors.violet]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 10),
                const Text('Lumina', style: TextStyle(
                  fontFamily: 'Syne', fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18)),
              ]),
            ),
          ),

          // ── CONTENT ────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                SlideTransition(
                  position: _cardsSlide,
                  child: FadeTransition(
                    opacity: _cardsFade,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Quick Actions 2×2 ─────────────────────────────
                        const SizedBox(height: 20),
                        _SectionLabel(label: 'Quick Actions'),
                        const SizedBox(height: 12),
                        Row(children: [
                          _QuickAction2(
                            icon: Icons.document_scanner_outlined,
                            label: 'Scan Timetable',
                            color: AppColors.indigo,
                            onTap: () => context.push('/ocr'),
                          ),
                          const SizedBox(width: 10),
                          _QuickAction2(
                            icon: Icons.psychology_rounded,
                            label: 'Ask Lumina AI',
                            color: AppColors.violet,
                            onTap: () => context.go('/rag'),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          _QuickAction2(
                            icon: Icons.add_card_rounded,
                            label: 'Log Expense',
                            color: AppColors.green,
                            onTap: () => context.go('/expenses'),
                          ),
                          const SizedBox(width: 10),
                          _QuickAction2(
                            icon: Icons.analytics_rounded,
                            label: 'Bunk Stats',
                            color: AppColors.amber,
                            onTap: () => context.push('/bunk'),
                          ),
                        ]),

                        // ── Today's Classes — Timeline ─────────────────────
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _SectionLabel(label: "Today's Classes"),
                            GestureDetector(
                              onTap: () => context.go('/home'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.indigo.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('View all',
                                  style: TextStyle(color: AppColors.indigo, fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        slotsAsync.when(
                          loading: () => Column(children: List.generate(3, (_) =>
                            const _SkeletonTile())),
                          error: (_, __) => _EmptyCard(
                            icon: Icons.wifi_off_rounded, label: 'No connection'),
                          data: (slots) {
                            final todaySlots = slots
                                .where((s) => (s['day_of_week'] as String?) == todayKey)
                                .toList()
                              ..sort((a, b) => (a['start_time'] as String? ?? '')
                                  .compareTo(b['start_time'] as String? ?? ''));
                            if (todaySlots.isEmpty) return _EmptyCard(
                              icon: Icons.free_breakfast_rounded,
                              label: 'No classes today 🎉',
                            );
                            final logs = logsAsync.value ?? {};
                            return _TimelineSchedule(
                              slots: todaySlots.take(5).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
                              logs: logs,
                              todayStr: todayStr,
                              now: now,
                            );
                          },
                        ),

                        // ── Next Class + Attendance Row ────────────────────
                        const SizedBox(height: 20),
                        Row(children: [
                          Expanded(
                            flex: 1,
                            child: analyticsAsync.when(
                              loading: () => const _SkeletonBox(height: 120),
                              error: (_, __) => _AttendanceRing(pct: 0, label: '--'),
                              data: (analytics) {
                                if (analytics.isEmpty) return _AttendanceRing(pct: 0, label: '0%');
                                final items = analytics.map((e) => e as Map<String, dynamic>).toList();
                                final avg = items
                                    .map((e) => (e['percentage'] as num?)?.toDouble() ?? 0.0)
                                    .reduce((a, b) => a + b) / items.length;
                                return _AttendanceRing(pct: avg / 100, label: '${avg.round()}%');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: slotsAsync.when(
                              loading: () => const _SkeletonBox(height: 120),
                              error: (_, __) => _NextClassCard(slot: null),
                              data: (slots) {
                                final todaySlots = slots
                                    .where((s) => (s['day_of_week'] as String?) == todayKey)
                                    .toList()
                                  ..sort((a, b) => (a['start_time'] as String? ?? '')
                                      .compareTo(b['start_time'] as String? ?? ''));
                                final upcoming = todaySlots.firstWhere((s) {
                                  try {
                                    final tp = (s['start_time'] as String?)?.split(':') ?? [];
                                    if (tp.length < 2) return false;
                                    final t = DateTime(now.year, now.month, now.day,
                                        int.parse(tp[0]), int.parse(tp[1]));
                                    return t.isAfter(now);
                                  } catch (_) { return false; }
                                }, orElse: () => <String, dynamic>{});
                                return _NextClassCard(slot: upcoming.isEmpty ? null : upcoming);
                              },
                            ),
                          ),
                        ]),

                        // ── Finance Snapshot ──────────────────────────────
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _SectionLabel(label: 'Finance Snapshot'),
                            GestureDetector(
                              onTap: () => context.go('/expenses'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Details',
                                  style: TextStyle(color: AppColors.green, fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        expensesAsync.when(
                          loading: () => const _SkeletonBox(height: 100),
                          error: (_, __) => _EmptyCard(icon: Icons.error_outline, label: 'No data'),
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
                            return _FinanceCard(
                              weekTotal: total, itemCount: thisWeek.length, budget: budget);
                          },
                        ),

                        // ── Study Squads ──────────────────────────────────
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _SectionLabel(label: 'Study Squads'),
                            GestureDetector(
                              onTap: () => context.go('/groups'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.violet.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('See all',
                                  style: TextStyle(color: AppColors.violet, fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        groupsAsync.when(
                          loading: () => const _SkeletonBox(height: 80),
                          error: (_, __) => _EmptyCard(icon: Icons.people_outline, label: 'No squads found'),
                          data: (groups) => _SquadsCard(
                            group: groups.isEmpty ? null : groups.first as Map<String, dynamic>),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HERO HEADER
// ══════════════════════════════════════════════════════════════════════════════
class _HeroHeader extends StatelessWidget {
  final String greeting, firstName;
  final DateTime now;
  final bool isDark;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;
  final VoidCallback onThemeToggle, onProfile;
  final AsyncValue analyticsAsync;

  const _HeroHeader({
    required this.greeting, required this.firstName, required this.now,
    required this.isDark, required this.fadeAnim, required this.slideAnim,
    required this.onThemeToggle, required this.onProfile,
    required this.analyticsAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF080B1F)]
              : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(top: -40, right: -40,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white.withOpacity(0.06), Colors.transparent]),
              ),
            ),
          ),
          Positioned(bottom: 10, left: -30,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.violet.withOpacity(0.3), Colors.transparent]),
              ),
            ),
          ),
          // Mesh dots
          Positioned.fill(child: CustomPaint(painter: _MeshDotPainter())),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: SlideTransition(
                position: slideAnim,
                child: FadeTransition(
                  opacity: fadeAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Container(
                                      width: 6, height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF4ADE80),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(DateFormat('EEEE, MMM d').format(now),
                                      style: const TextStyle(color: Colors.white70, fontSize: 10,
                                        fontWeight: FontWeight.w600)),
                                  ]),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              Text(greeting,
                                style: const TextStyle(
                                  color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text(firstName,
                                style: const TextStyle(
                                  fontFamily: 'Syne', fontSize: 32, fontWeight: FontWeight.w800,
                                  color: Colors.white, height: 1.1)),
                            ],
                          ),
                        ),
                        Column(children: [
                          _HeroBtn(
                            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            onTap: onThemeToggle,
                          ),
                          const SizedBox(height: 8),
                          _HeroBtn(icon: Icons.person_rounded, onTap: onProfile),
                        ]),
                      ]),

                      const SizedBox(height: 18),
                      // Attendance summary pill
                      analyticsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (analytics) {
                          if (analytics == null || (analytics as List).isEmpty) return const SizedBox.shrink();
                          final items = analytics.map((e) => e as Map<String, dynamic>).toList();
                          final avg = items
                              .map((e) => (e['percentage'] as num?)?.toDouble() ?? 0.0)
                              .reduce((a, b) => a + b) / items.length;
                          final color = avg >= 75
                              ? const Color(0xFF4ADE80)
                              : avg >= 60
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFFF87171);
                          final label = avg >= 75 ? 'Safe' : avg >= 60 ? 'Borderline' : 'At Risk';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.18)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)]),
                              ),
                              const SizedBox(width: 8),
                              Text('Attendance ${avg.round()}% · $label',
                                style: const TextStyle(color: Colors.white, fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                            ]),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeroBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

// Subtle mesh dot pattern for hero background
class _MeshDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.04);
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION LABEL
// ══════════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 3, height: 16,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.indigo, AppColors.violet],
            begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(
        fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// QUICK ACTIONS 2x2
// ══════════════════════════════════════════════════════════════════════════════
class _QuickAction2 extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction2({required this.icon, required this.label,
    required this.color, required this.onTap});

  @override
  State<_QuickAction2> createState() => _QuickAction2State();
}

class _QuickAction2State extends State<_QuickAction2>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) { _pressCtrl.forward(); HapticFeedback.selectionClick(); },
        onTapUp: (_) { _pressCtrl.reverse(); widget.onTap(); },
        onTapCancel: () => _pressCtrl.reverse(),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: isDark
                  ? widget.color.withOpacity(0.12)
                  : widget.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.color.withOpacity(isDark ? 0.3 : 0.2),
              ),
              boxShadow: isDark
                  ? [BoxShadow(
                      color: widget.color.withOpacity(0.15),
                      blurRadius: 16, offset: const Offset(0, 4))]
                  : [BoxShadow(
                      color: widget.color.withOpacity(0.12),
                      blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(widget.label,
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Syne',
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TIMELINE SCHEDULE
// ══════════════════════════════════════════════════════════════════════════════
class _TimelineSchedule extends StatelessWidget {
  final List<Map<String, dynamic>> slots;
  final Map logs;
  final String todayStr;
  final DateTime now;
  const _TimelineSchedule({required this.slots, required this.logs,
    required this.todayStr, required this.now});

  bool _isNow(Map<String, dynamic> slot) {
    try {
      final sp = (slot['start_time'] as String?)?.split(':') ?? [];
      final ep = (slot['end_time'] as String?)?.split(':') ?? [];
      if (sp.length < 2 || ep.length < 2) return false;
      final start = DateTime(now.year, now.month, now.day,
        int.parse(sp[0]), int.parse(sp[1]));
      final end = DateTime(now.year, now.month, now.day,
        int.parse(ep[0]), int.parse(ep[1]));
      return now.isAfter(start) && now.isBefore(end);
    } catch (_) { return false; }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = context.isDark;
    return Column(
      children: List.generate(slots.length, (i) {
        final slot = slots[i];
        final isLast = i == slots.length - 1;
        final subject = slot['subject'] as Map? ?? {};
        final subjectName = subject['name'] as String? ?? 'Unknown';
        final start = slot['start_time'] as String? ?? '';
        final end   = slot['end_time']   as String? ?? '';
        final type  = slot['slot_type']  as String? ?? 'lecture';
        final colorHex = subject['color_hex'] as String? ?? '#6366F1';
        Color c = AppColors.indigo;
        try { c = Color(int.parse(colorHex.replaceFirst('#', 'FF'), radix: 16)); } catch (_) {}
        final isNow    = _isNow(slot);
        final status   = logs['${slot['id']}_$todayStr'] as String?;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline spine
              SizedBox(
                width: 36,
                child: Column(
                  children: [
                    // Dot
                    Container(
                      width: isNow ? 14 : 10,
                      height: isNow ? 14 : 10,
                      decoration: BoxDecoration(
                        color: isNow ? c : (isDark ? AppColors.darkCard : Colors.white),
                        shape: BoxShape.circle,
                        border: Border.all(color: c, width: isNow ? 0 : 2),
                        boxShadow: isNow
                            ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 10)]
                            : null,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: c.withOpacity(0.2),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Card
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: isNow
                        ? c.withOpacity(isDark ? 0.15 : 0.08)
                        : (isDark ? AppColors.darkCard : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isNow ? c.withOpacity(0.5) : c.withOpacity(0.15),
                      width: isNow ? 1.5 : 1,
                    ),
                    boxShadow: isNow && isDark
                        ? [BoxShadow(color: c.withOpacity(0.2), blurRadius: 16)]
                        : !isDark
                            ? [BoxShadow(color: Colors.black.withOpacity(0.05),
                                blurRadius: 8, offset: const Offset(0, 2))]
                            : null,
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (isNow)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: c, borderRadius: BorderRadius.circular(6)),
                            child: const Text('NOW',
                              style: TextStyle(color: Colors.white, fontSize: 8,
                                fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                          ),
                        Text(subjectName,
                          style: TextStyle(
                            fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 13,
                            color: cs.onSurface)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.schedule_rounded, size: 11, color: c),
                          const SizedBox(width: 3),
                          Text('$start – $end',
                            style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: c.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(type[0].toUpperCase() + type.substring(1),
                              style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ]),
                    ),
                    if (status != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (status == 'present' ? AppColors.green : AppColors.rose)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          status == 'present'
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 16,
                          color: status == 'present' ? AppColors.green : AppColors.rose,
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ATTENDANCE RING
// ══════════════════════════════════════════════════════════════════════════════
class _AttendanceRing extends StatelessWidget {
  final double pct;
  final String label;
  const _AttendanceRing({required this.pct, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final color = pct >= 0.75 ? AppColors.green : pct >= 0.60 ? AppColors.amber : AppColors.rose;
    final statusLabel = pct >= 0.75 ? 'Safe' : pct >= 0.60 ? 'Borderline' : 'At Risk';
    return Container(
      height: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: isDark
            ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 20)]
            : [BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 64, height: 64,
              child: CircularProgressIndicator(
                value: pct,
                strokeWidth: 7,
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation(color),
                strokeCap: StrokeCap.round,
              ),
            ),
            Text(label,
              style: TextStyle(
                fontFamily: 'Syne', fontWeight: FontWeight.w800,
                fontSize: 15, color: color)),
          ]),
          const SizedBox(height: 6),
          Text(statusLabel,
            style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w700)),
          Text('Attendance',
            style: TextStyle(
              fontSize: 9,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// NEXT CLASS CARD
// ══════════════════════════════════════════════════════════════════════════════
class _NextClassCard extends StatelessWidget {
  final Map? slot;
  const _NextClassCard({this.slot});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final cs = Theme.of(context).colorScheme;

    if (slot == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.indigo.withOpacity(0.1)),
        ),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.done_all_rounded,
            color: AppColors.green.withOpacity(0.7), size: 28),
          const SizedBox(height: 6),
          Text('All done today!', textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withOpacity(0.5),
              fontSize: 12, fontWeight: FontWeight.w600)),
        ])),
      );
    }

    final subject = slot!['subject'] as Map? ?? {};
    final name  = subject['name'] as String? ?? 'Class';
    final start = slot!['start_time'] as String? ?? '';
    final type  = slot!['slot_type']  as String? ?? 'lecture';
    final color = type == 'lab' ? AppColors.cyan : AppColors.indigo;

    // Countdown
    String countdown = '';
    try {
      final tp = start.split(':');
      if (tp.length >= 2) {
        final now = DateTime.now();
        final t = DateTime(now.year, now.month, now.day, int.parse(tp[0]), int.parse(tp[1]));
        final diff = t.difference(now);
        if (diff.inMinutes > 0)
          countdown = 'in ${diff.inMinutes}m';
      }
    } catch (_) {}

    return Container(
      height: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [color.withOpacity(0.25), color.withOpacity(0.08)]
              : [color.withOpacity(0.12), color.withOpacity(0.03)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.35)),
        boxShadow: isDark
            ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 20)]
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(20)),
            child: const Text('NEXT', style: TextStyle(
              color: Colors.white, fontSize: 8,
              fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
          const Spacer(),
          if (countdown.isNotEmpty)
            Text(countdown, style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
        const Spacer(),
        Text(name,
          style: TextStyle(
            fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 14,
            color: cs.onSurface),
          maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.access_time_filled_rounded, size: 11, color: color),
          const SizedBox(width: 3),
          Text(start, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
            child: Text(type, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FINANCE CARD
// ══════════════════════════════════════════════════════════════════════════════
class _FinanceCard extends StatelessWidget {
  final double weekTotal, budget;
  final int itemCount;
  const _FinanceCard({required this.weekTotal, required this.itemCount,
    required this.budget});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final cs = Theme.of(context).colorScheme;
    final pct   = budget > 0 ? (weekTotal / budget).clamp(0.0, 1.0) : 0.0;
    final color = pct < 0.6 ? AppColors.green : pct < 0.85 ? AppColors.amber : AppColors.rose;
    final remaining = (budget - weekTotal).clamp(0.0, budget);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: isDark
            ? [BoxShadow(color: color.withOpacity(0.08), blurRadius: 20)]
            : [BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.account_balance_wallet_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('This Week', style: TextStyle(
                color: cs.onSurface.withOpacity(0.5), fontSize: 11)),
              Text('₹${weekTotal.toStringAsFixed(0)}',
                style: TextStyle(
                  fontFamily: 'Syne', fontWeight: FontWeight.w800,
                  fontSize: 24, color: color)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$itemCount txns', style: TextStyle(
              color: cs.onSurface.withOpacity(0.4), fontSize: 11)),
            Text('₹${remaining.toStringAsFixed(0)} left',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ]),
        const SizedBox(height: 14),
        // Gradient progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(children: [
            Container(
              height: 8,
              color: color.withOpacity(0.12),
            ),
            FractionallySizedBox(
              widthFactor: pct,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: pct < 0.6
                        ? [AppColors.green, const Color(0xFF34D399)]
                        : pct < 0.85
                            ? [AppColors.amber, const Color(0xFFFBBF24)]
                            : [AppColors.rose, const Color(0xFFFB7185)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${(pct * 100).toStringAsFixed(0)}% of ₹${budget.toStringAsFixed(0)} budget',
              style: TextStyle(color: cs.onSurface.withOpacity(0.4), fontSize: 10)),
            Text(pct < 0.6 ? '✅ Under budget' : pct < 0.85 ? '⚠️ Almost there' : '🔴 Over!',
              style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STUDY SQUADS CARD
// ══════════════════════════════════════════════════════════════════════════════
class _SquadsCard extends StatelessWidget {
  final Map<String, dynamic>? group;
  const _SquadsCard({this.group});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final cs = Theme.of(context).colorScheme;
    final name = group?['name'] as String? ?? 'Join a Squad';
    final desc = group?['description'] as String? ?? 'Study together, grow together';

    final hue = name.codeUnits.fold(0, (a, b) => a + b) % 360;
    final accentColor = HSLColor.fromAHSL(1, hue.toDouble(), 0.65, isDark ? 0.6 : 0.5).toColor();

    return GestureDetector(
      onTap: () => context.go('/groups'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [accentColor.withOpacity(0.15), AppColors.darkCard]
                : [accentColor.withOpacity(0.06), Colors.white],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(0.25)),
          boxShadow: isDark
              ? [BoxShadow(color: accentColor.withOpacity(0.1), blurRadius: 20)]
              : [BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withOpacity(0.7)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color: accentColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Center(child: Text(name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                fontSize: 18, fontFamily: 'Syne'))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(
              fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 14,
              color: cs.onSurface)),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(
              color: cs.onSurface.withOpacity(0.5), fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                color: accentColor.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: const Text('Open', style: TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SKELETON / EMPTY
// ══════════════════════════════════════════════════════════════════════════════
class _SkeletonBox extends StatelessWidget {
  final double height;
  const _SkeletonBox({required this.height});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      height: 60, margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: cs.onSurface.withOpacity(0.3)),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(
          color: cs.onSurface.withOpacity(0.45), fontSize: 13)),
      ]),
    );
  }
}
