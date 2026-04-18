import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/shimmer_widgets.dart';
import 'timetable_provider.dart';
import 'edit_slot_sheet.dart';
import '../../shared/providers/profile_provider.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});
  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _daysFull = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

  static const List<Color> _slotPalette = [
    AppColors.indigo, AppColors.green, AppColors.amber,
    Color(0xFFEC4899), AppColors.cyan, AppColors.violet, AppColors.rose,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.invalidate(timetableProvider);
      final profile = await ref.read(timetableProvider.notifier).checkProfile();
      if (profile != null && profile['division'] == null && mounted) {
        _showOnboardingFlow();
      }
    });
  }

  void _showOnboardingFlow() {
    String div = 'A';
    String batch = 'A';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setInnerState) {
        return Dialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22), 
            side: BorderSide(color: AppColors.indigo.withOpacity(0.4))
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.school_outlined, color: AppColors.indigo, size: 40),
              const SizedBox(height: 16),
              Text('Welcome to Lumina', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Syne')),
              const SizedBox(height: 8),
              Text('Set your Division and Batch to auto-generate your timetable.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.55), fontSize: 13)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: div,
                  dropdownColor: Theme.of(ctx).colorScheme.surface,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
                  decoration: const InputDecoration(labelText: 'Division', border: OutlineInputBorder()),
                  items: ['A', 'B', 'C', 'D'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setInnerState(() => div = v!),
                )),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String>(
                  value: batch,
                  dropdownColor: Theme.of(ctx).colorScheme.surface,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
                  decoration: const InputDecoration(labelText: 'Batch', border: OutlineInputBorder()),
                  items: ['A', 'B', 'C', 'D'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setInnerState(() => batch = v!),
                )),
              ]),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: Container(
                decoration: DesignStyles.gradientButton(),
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(timetableProvider.notifier).updateProfileAndGenerate(div, batch);
                  },
                  child: const Text('Generate Timetable', style: TextStyle(color: Colors.white)),
                ),
              )),
            ]),
          ),
        );
      }),
    );
  }

  // _markAttendance removed, now using TimetableNotifier directly

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(timetableProvider);
    final now = DateTime.now();
    final todayLabel = DateFormat('EEEE, MMMM d').format(now);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: slotsAsync.when(
        loading: () => const TimetableShimmer(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_outlined, size: 48, color: AppColors.rose),
            const SizedBox(height: 12),
            Text('$e', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              decoration: DesignStyles.gradientButton(),
              child: FilledButton.icon(
                onPressed: () => ref.invalidate(timetableProvider),
                style: FilledButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
          ]),
        ),
      ),
        data: (slots) {
          final grouped = <String, List<dynamic>>{
            for (final d in _daysFull) d: [],
          };
          for (final slot in slots) {
            final day = slot['day_of_week'] as String? ?? '';
            grouped[day]?.add(slot);
          }

          final todayKey = DateFormat('EEEE').format(now).toLowerCase();
          final todaySlots = grouped[todayKey] ?? [];

          final analytics = ref.watch(bunkAnalyticsProvider).value ?? [];
          final items = analytics.map((e) => e as Map<String, dynamic>).toList();
          
          double avgPct = 0;
          int bunksLeft = 0;
          
          if (items.isNotEmpty) {
            avgPct = items.map((e) => (e['percentage'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / items.length;
            bunksLeft = items.map((e) => (e['bunks_remaining'] as num?)?.toInt() ?? 0).where((b) => b > 0).fold<int>(0, (a, b) => a + b);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Premium glass header ──────────────────────────────────
              _Header(
                todayLabel: todayLabel,
                classesToday: todaySlots.length,
                avgAttendance: avgPct,
                bunksLeft: bunksLeft,
                hasSlots: slots.isNotEmpty,
                onBunk: () => context.go('/bunk'),
                onDelete: () => _confirmDelete(context, ref),
                onScan: () => context.go('/ocr'),
              ),

              // ── Semester Progress Banner ──────────────────────────────
              if (slots.isNotEmpty) _SemesterProgressBanner(),

              // ── Main Content Area ──────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.indigo,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  onRefresh: () async => ref.invalidate(timetableProvider),
                  child: slots.isEmpty
                    ? ListView(padding: const EdgeInsets.all(18), children: [_EmptyTimetable(onScan: () => context.go('/ocr'))])
                    : CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          // ── Today's Vertical Timeline ─────────────────
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                            sliver: SliverToBoxAdapter(
                              child: Text("Today's Journey",
                                style: TextStyle(
                                  fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 18,
                                  color: Theme.of(context).colorScheme.onSurface)),
                            ),
                          ),
                          if (todaySlots.isEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              sliver: SliverToBoxAdapter(child: _FreeDayCard()),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (ctx, i) => _TimelineItem(
                                    slot: todaySlots[i],
                                    isFirst: i == 0,
                                    isLast: i == todaySlots.length - 1,
                                    analytics: items.firstWhere(
                                      (a) => a['subject_name'] == todaySlots[i]['subject']['name'],
                                      orElse: () => {},
                                    ),
                                  ),
                                  childCount: todaySlots.length,
                                ),
                              ),
                            ),

                          // ── Weekly Overview ────────────────────────────
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 30, 18, 10),
                            sliver: SliverToBoxAdapter(
                              child: Text("Weekly Glimpse",
                                style: TextStyle(
                                  fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 18,
                                  color: Theme.of(context).colorScheme.onSurface)),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 50),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) {
                                  final day = _daysFull[i];
                                  if (day == todayKey) return const SizedBox.shrink();
                                  return _DaySummaryCard(
                                    dayAbbr: _days[i],
                                    dayFull: day,
                                    slots: grouped[day] ?? [],
                                  );
                                },
                                childCount: _daysFull.length,
                              ),
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }


  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: AppColors.indigo.withOpacity(0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.rose, size: 24),
              SizedBox(width: 10),
              Text('Delete Timetable?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'Syne')),
            ]),
            const SizedBox(height: 10),
            const Text('This will permanently delete all your classes, subjects, and attendance records. This cannot be undone.',
              style: TextStyle(fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  side: BorderSide(color: AppColors.border(context)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(
                onPressed: () {
                  ref.read(timetableProvider.notifier).deleteTimetable();
                  Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete'),
              )),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Header with gradient + stats ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String todayLabel;
  final int classesToday;
  final double avgAttendance;
  final int bunksLeft;
  final bool hasSlots;
  final VoidCallback onBunk, onDelete, onScan;

  const _Header({
    required this.todayLabel,
    required this.classesToday,
    required this.avgAttendance,
    required this.bunksLeft,
    required this.hasSlots,
    required this.onBunk,
    required this.onDelete,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 50, 18, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0x1A6366F1), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(todayLabel, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('My Timetable',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
          ]),
          Row(children: [
            _HeaderBtn(icon: Icons.person_outline, onTap: () => context.push('/profile')),
            const SizedBox(width: 8),
            if (!hasSlots)
              _HeaderBtn(icon: Icons.document_scanner_outlined, onTap: onScan),
            if (!hasSlots) const SizedBox(width: 8),
            _HeaderBtn(icon: Icons.analytics_outlined, onTap: onBunk),
            if (hasSlots) ...[
              const SizedBox(width: 8),
              _HeaderBtn(icon: Icons.delete_outline, onTap: onDelete, color: AppColors.rose),
            ],
          ]),
        ]),
        const SizedBox(height: 14),
        // Stats pills
        Row(children: [
          _StatPill(emoji: '📚', label: 'Today', value: '$classesToday', color: AppColors.indigo),
          const SizedBox(width: 10),
          _StatPill(emoji: '✅', label: 'Avg Att.', value: '${avgAttendance.round()}%', color: AppColors.green),
          const SizedBox(width: 10),
          _StatPill(emoji: '😈', label: 'Bunks Left', value: '$bunksLeft', color: AppColors.amber),
        ]),
      ]),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _HeaderBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: Icon(icon, color: color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.5), size: 18),
    ),
  );
}

class _StatPill extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  const _StatPill({required this.emoji, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _SemesterProgressBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    
    return profileAsync.when(
      data: (profile) {
        final startStr = profile['semester_start'] as String?;
        final endStr = profile['semester_end'] as String?;
        
        if (startStr == null || endStr == null) return const SizedBox.shrink();
        
        final start = DateTime.parse(startStr);
        final end = DateTime.parse(endStr);
        final now = DateTime.now();
        
        if (now.isBefore(start) || now.isAfter(end)) return const SizedBox.shrink();
        
        final totalDays = end.difference(start).inDays;
        final daysPassed = now.difference(start).inDays;
        final progress = (daysPassed / totalDays).clamp(0.0, 1.0);
        final currentWeek = (daysPassed / 7).ceil();
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.indigo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.indigo.withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.auto_awesome, color: AppColors.indigo, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Week $currentWeek of Semester', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.indigo, fontFamily: 'Syne')),
                Text('Keep going! ${(progress * 100).round()}% of your cycle is complete.', style: TextStyle(fontSize: 11, color: AppColors.indigo.withOpacity(0.7))),
              ]),
            ),
            SizedBox(
              width: 40, height: 40,
              child: CircularProgressIndicator(
                value: progress, 
                strokeWidth: 5, 
                backgroundColor: AppColors.indigo.withOpacity(0.1),
                color: AppColors.indigo,
              ),
            ),
          ]),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TimelineItem extends ConsumerStatefulWidget {
  final dynamic slot;
  final bool isFirst, isLast;
  final Map<String, dynamic> analytics;

  const _TimelineItem({required this.slot, required this.isFirst, required this.isLast, required this.analytics});

  @override
  ConsumerState<_TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends ConsumerState<_TimelineItem> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final slotId = slot['id'] as String? ?? '';
    final subject = slot['subject'] as Map<String, dynamic>? ?? {};
    final colorHex = subject['color_hex'] as String? ?? '#6366F1';
    final Color slotColor = Color(int.parse(colorHex.replaceFirst('#', 'FF'), radix: 16));
    
    final startTime = slot['start_time'] as String? ?? '';
    final endTime = slot['end_time'] as String? ?? '';
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final logsMap = ref.watch(attendanceLogsProvider).value ?? {};
    final marked = logsMap['${slotId}_$todayStr'];

    final bunksLeft = widget.analytics['bunks_remaining'] ?? 0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline Stem ──────────────────────────────────────
          SizedBox(
            width: 30,
            child: Column(children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: slotColor, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: slotColor.withOpacity(0.5), blurRadius: 8)],
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              if (!widget.isLast)
                Expanded(
                  child: Container(width: 2, color: slotColor.withOpacity(0.2)),
                ),
            ]),
          ),
          // ── Content Card ───────────────────────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: AppStyles.glassCard(context).copyWith(
                 border: Border.all(color: slotColor.withOpacity(0.2)),
              ),
              child: InkWell(
                onTap: () => showEditSlotSheet(context, ref, slot),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(startTime, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: slotColor)),
                      _TypePill(label: slot['slot_type'] ?? 'lecture', color: slotColor),
                    ]),
                    const SizedBox(height: 8),
                    Text(subject['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Syne')),
                    if (subject['teacher'] != null)
                      Text('with ${subject['teacher']}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                    const SizedBox(height: 12),
                    
                    // ── Analytics / Actions ───────────────────────
                    if (marked != null && !_isEditing)
                      _AttendanceIndicator(
                        status: marked, 
                        onEdit: () => setState(() => _isEditing = true)
                      )
                    else
                      _AttendanceActions(
                        slotId: slotId, 
                        todayStr: todayStr, 
                        onMark: (s) async {
                          await ref.read(timetableProvider.notifier).markAttendance(slotId, todayStr, s);
                          setState(() => _isEditing = false);
                        }
                      ),
                    
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.info_outline, size: 12, color: AppColors.indigo),
                      const SizedBox(width: 6),
                      Text('Bunk budget: You can miss $bunksLeft more this year.', 
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (bunksLeft as num) > 0 ? AppColors.indigo : AppColors.rose)),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceIndicator extends ConsumerWidget {
  final String status;
  final VoidCallback? onEdit;
  const _AttendanceIndicator({required this.status, this.onEdit});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (status == 'present' ? AppColors.green : AppColors.rose).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(status == 'present' ? Icons.check_circle : Icons.cancel, size: 14, color: status == 'present' ? AppColors.green : AppColors.rose),
          const SizedBox(width: 6),
          Text(status == 'present' ? 'Present' : 'Bunked', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: status == 'present' ? AppColors.green : AppColors.rose)),
        ]),
      ),
      const SizedBox(width: 4),
      // Use InkWell for better hit area than a tiny TextButton
      InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
              const SizedBox(width: 4),
              Text('Edit', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    ],
  );
}

class _AttendanceActions extends StatefulWidget {
  final String slotId, todayStr;
  final Future<void> Function(String) onMark;
  const _AttendanceActions({required this.slotId, required this.todayStr, required this.onMark});

  @override
  State<_AttendanceActions> createState() => _AttendanceActionsState();
}

class _AttendanceActionsState extends State<_AttendanceActions> {
  String? _loadingStatus;

  Future<void> _handleMark(String status) async {
    setState(() => _loadingStatus = status);
    try {
      await widget.onMark(status);
    } finally {
      if (mounted) setState(() => _loadingStatus = null);
    }
  }

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _ActionBtn(
      label: 'Present', 
      icon: Icons.check, 
      color: AppColors.green, 
      isLoading: _loadingStatus == 'present',
      onTap: () => _handleMark('present')
    )),
    const SizedBox(width: 10),
    Expanded(child: _ActionBtn(
      label: 'Bunk', 
      icon: Icons.close, 
      color: AppColors.rose, 
      isLoading: _loadingStatus == 'absent',
      onTap: () => _handleMark('absent')
    )),
  ]);
}

class _ActionBtn extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap; final bool isLoading;
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: isLoading ? null : onTap,
    icon: isLoading 
      ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: color))
      : Icon(icon, size: 14), 
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: color, side: BorderSide(color: color.withOpacity(0.3)),
      padding: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

class _DaySummaryCard extends ConsumerWidget {
  final String dayAbbr, dayFull;
  final List<dynamic> slots;
  const _DaySummaryCard({required this.dayAbbr, required this.dayFull, required this.slots});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: AppStyles.glassCard(context),
    child: InkWell(
      onTap: () => _showDayDetail(context, ref, dayFull, slots),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 45, height: 45,
            decoration: BoxDecoration(color: AppColors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(dayAbbr, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.indigo, fontFamily: 'Syne'))),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dayFull[0].toUpperCase() + dayFull.substring(1), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text('${slots.length} classes scheduled', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
        ]),
      ),
    ),
  );

  void _showDayDetail(BuildContext context, WidgetRef ref, String day, List<dynamic> daySlots) {
    // Calculate the date for this day in the current week
    final now = DateTime.now();
    final dayIndex = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'].indexOf(day.toLowerCase());
    final currentDayIndex = now.weekday - 1; // 0 = Monday
    final dateForDay = now.add(Duration(days: dayIndex - currentDayIndex));
    final dateStr = DateFormat('yyyy-MM-dd').format(dateForDay);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(day[0].toUpperCase() + day.substring(1), style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 22)),
              Text(DateFormat('MMMM d, yyyy').format(dateForDay), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            ]),
            IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 20),
          Expanded(
            child: daySlots.isEmpty 
              ? const Center(child: Text('No classes this day!'))
              : ListView.builder(
                  itemCount: daySlots.length,
                  itemBuilder: (ctx, i) {
                    return _BottomSheetSlotItem(
                      slot: daySlots[i],
                      dateStr: dateStr,
                    );
                  },
                ),
          ),
        ]),
      ),
    );
  }
}

class _FreeDayCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(30),
    decoration: AppStyles.glassCard(context),
    child: Column(children: [
      const Text('🎉', style: TextStyle(fontSize: 40)),
      const SizedBox(height: 12),
      const Text('Free day!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, fontFamily: 'Syne')),
      Text('No classes scheduled for today. Time to relax or study!', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
    ]),
  );
}

class _BottomSheetSlotItem extends ConsumerStatefulWidget {
  final dynamic slot;
  final String dateStr;
  const _BottomSheetSlotItem({required this.slot, required this.dateStr});

  @override
  ConsumerState<_BottomSheetSlotItem> createState() => _BottomSheetSlotItemState();
}

class _BottomSheetSlotItemState extends ConsumerState<_BottomSheetSlotItem> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final slotId = slot['id'] as String? ?? '';
    final subject = slot['subject'] as Map<String, dynamic>? ?? {};
    final colorHex = subject['color_hex'] as String? ?? '#6366F1';
    final color = Color(int.parse(colorHex.replaceFirst('#', 'FF'), radix: 16));
    
    final logsMap = ref.watch(attendanceLogsProvider).value ?? {};
    final marked = logsMap['${slotId}_${widget.dateStr}'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.glassCard(context).copyWith(
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(slot['start_time'], style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            Text(slot['end_time'], style: TextStyle(fontSize: 10, color: color.withOpacity(0.5))),
          ]),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(subject['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(slot['slot_type'] ?? 'Lecture', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          ])),
        ]),
        const SizedBox(height: 12),
        if (marked != null && !_isEditing)
          _AttendanceIndicator(
            status: marked, 
            onEdit: () => setState(() => _isEditing = true)
          )
        else
          _AttendanceActions(
            slotId: slotId, 
            todayStr: widget.dateStr, 
            onMark: (s) async {
              await ref.read(timetableProvider.notifier).markAttendance(slotId, widget.dateStr, s);
              setState(() => _isEditing = false);
            }
          ),
      ]),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final Color color;
  const _TypePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.13),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.35)),
    ),
    child: Text(
      label[0].toUpperCase() + label.substring(1),
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.4),
    ),
  );
}

// ── Collapsible Day Section ───────────────────────────────────────────────────
class _DaySection extends ConsumerWidget {
  final String dayAbbr, dayFull;
  final List<dynamic> slots;
  final List<Color> palette;
  final bool isToday;
  const _DaySection({required this.dayAbbr, required this.dayFull, required this.slots, required this.palette, required this.isToday});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isToday ? AppColors.indigo.withOpacity(0.15) : Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isToday ? AppColors.indigo.withOpacity(0.4) : Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
            ),
            child: Center(child: Text(dayAbbr,
              style: TextStyle(color: isToday ? AppColors.indigo : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontWeight: FontWeight.w800, fontSize: 12, fontFamily: 'Syne'))),
          ),
          const SizedBox(width: 10),
          Text('${slots.length} class${slots.length == 1 ? '' : 'es'}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
          if (isToday) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.indigo.withOpacity(0.12), 
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.indigo.withOpacity(0.2)),
              ),
              child: const Text('Today', style: TextStyle(color: AppColors.indigo, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        if (slots.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.free_breakfast_outlined, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), size: 16),
              const SizedBox(width: 8),
              Text('Free day 🎉', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 12)),
            ]),
          )
        else
          ...List.generate(slots.length, (i) {
            final slot = slots[i];
            final subject = slot['subject'] as Map<String, dynamic>? ?? {};
            final colorHex = subject['color_hex'] as String? ?? '#6366F1';
            Color slotColor;
            try { slotColor = Color(int.parse(colorHex.replaceFirst('#', 'FF'), radix: 16)); }
            catch (_) { slotColor = palette[i % palette.length]; }
            final slotType = slot['slot_type'] as String? ?? 'lecture';

            return GestureDetector(
              onTap: () => showEditSlotSheet(context, ref, slot),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: slotColor, width: 3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(subject['name'] ?? 'Unknown',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${slot['start_time']} – ${slot['end_time']}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 10, height: 1.5)),
                  ])),
                  _TypePill(label: slotType, color: slotColor),
                ],
              ),
             ),
            );
          }),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyTimetable extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyTimetable({required this.onScan});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 40),
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          shape: BoxShape.circle, 
          color: AppColors.indigo.withOpacity(context.isDark ? 0.15 : 0.08)
        ),
        child: const Icon(Icons.calendar_view_week_outlined, color: AppColors.indigo, size: 48),
      ),
      const SizedBox(height: 20),
      Text('No Timetable Yet',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 18, fontFamily: 'Syne')),
      const SizedBox(height: 8),
      Text('Upload a photo or PDF of your class schedule and Gemini AI will extract all slots automatically.',
        textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 13, height: 1.5)),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: onScan,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: DesignStyles.gradientButton(),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.document_scanner_outlined, color: Colors.white),
            SizedBox(width: 10),
            Text('Import via OCR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
      ),
    ],
  );
}
