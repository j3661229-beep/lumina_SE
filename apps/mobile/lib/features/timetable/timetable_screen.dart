import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/shimmer_widgets.dart';
import 'timetable_provider.dart';
import 'edit_slot_sheet.dart';

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
              // ── Indigo gradient header ──────────────────────────────────
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

              // ── Today's timeline ────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.indigo,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  onRefresh: () async => ref.invalidate(timetableProvider),
                  child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  children: [
                    if (slots.isEmpty)
                      _EmptyTimetable(onScan: () => context.go('/ocr'))
                    else ...[
                      // ── Today's schedule ──────────────────────────────
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Today's Schedule",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontFamily: 'Syne', fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface)),
                            GestureDetector(
                              onTap: () => context.go('/bunk'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
                                ),
                                child: Text('📊 Analytics',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (todaySlots.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
                          ),
                          child: Row(children: [
                            const Text('🎉', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Text('Free day! No classes today.',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 13)),
                          ]),
                        )
                      else
                        _TimelineList(slots: todaySlots, palette: _slotPalette),

                      // ── Rest of week ──────────────────────────────────
                      const SizedBox(height: 20),
                      Text('All Days',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: 'Syne', fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(height: 12),
                      ...List.generate(_days.length, (i) {
                        final day = _daysFull[i];
                        final daySlots = grouped[day] ?? [];
                        return _DaySection(
                          dayAbbr: _days[i],
                          dayFull: day,
                          slots: daySlots,
                          palette: _slotPalette,
                          isToday: day == todayKey,
                        );
                      }),
                    ],
                  ],
                ),
                ),  // closes RefreshIndicator
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

// ── Timeline list for today's slots ──────────────────────────────────────────
class _TimelineList extends ConsumerWidget {
  final List<dynamic> slots;
  final List<Color> palette;
  const _TimelineList({required this.slots, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: List.generate(slots.length, (i) {
        final slot = slots[i];
        final slotId = slot['id'] as String? ?? '';
        final subject = slot['subject'] as Map<String, dynamic>? ?? {};
        final colorHex = subject['color_hex'] as String? ?? '#6366F1';
        Color slotColor;
        try {
          slotColor = Color(int.parse(colorHex.replaceFirst('#', 'FF'), radix: 16));
        } catch (_) {
          slotColor = palette[i % palette.length];
        }
        final slotType = slot['slot_type'] as String? ?? 'Lecture';
        final startTime = slot['start_time'] as String? ?? '';
        final endTime = slot['end_time'] as String? ?? '';
        final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final logsMap = ref.watch(attendanceLogsProvider).value ?? {};
        final marked = logsMap['${slotId}_$todayStr'];

        Future<void> handleMark(String status) async {
          try {
            await ref.read(timetableProvider.notifier).markAttendance(slotId, todayStr, status);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(status == 'present' ? '✅ Marked present' : '🚫 Marked absent'),
                backgroundColor: status == 'present' ? AppColors.green : AppColors.rose,
                duration: const Duration(seconds: 1),
              ));
            }
          } catch (e) {
            debugPrint('[Timeline] mark failed: $e');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Failed to save attendance'),
                backgroundColor: AppColors.rose,
              ));
            }
          }
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left time + connector
            SizedBox(
              width: 52,
              child: Column(children: [
                const SizedBox(height: 14),
                Text(startTime, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35), fontSize: 10, height: 1)),
              ]),
            ),
            // Dot + line
            Column(children: [
              const SizedBox(height: 12),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: slotColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: slotColor.withOpacity(0.6), blurRadius: 8)],
                ),
              ),
              if (i < slots.length - 1)
                Container(
                  width: 2, height: 82,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [slotColor.withOpacity(0.6), Colors.transparent],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ]),
            const SizedBox(width: 10),
            // Card
            Expanded(
              child: GestureDetector(
                onTap: () => showEditSlotSheet(context, ref, slot),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border(left: BorderSide(color: slotColor, width: 3)),
                    boxShadow: [
                      BoxShadow(
                        color: slotColor.withOpacity(0.07),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(subject['name'] ?? 'Unknown',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 13, fontFamily: 'Syne')),
                        Text('$startTime – $endTime · ${slotType[0].toUpperCase()}${slotType.substring(1)}',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 10, height: 1.5)),
                      ])),
                      _TypePill(label: slotType, color: slotColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ── Attendance action row ──────────────────────────────
                  if (marked != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (marked == 'present' ? AppColors.green : AppColors.rose).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(marked == 'present' ? Icons.check_circle_outline : Icons.cancel_outlined,
                          size: 13, color: marked == 'present' ? AppColors.green : AppColors.rose),
                        const SizedBox(width: 5),
                        Text(marked == 'present' ? 'Marked Present' : 'Marked Absent',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: marked == 'present' ? AppColors.green : AppColors.rose)),
                      ]),
                    )
                  else
                    Row(children: [
                      Expanded(child: GestureDetector(
                        onTap: slotId.isEmpty ? null : () => handleMark('present'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.green.withOpacity(0.3)),
                          ),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.check_rounded, size: 13, color: AppColors.green),
                            SizedBox(width: 4),
                            Text('Present', style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: GestureDetector(
                        onTap: slotId.isEmpty ? null : () => handleMark('absent'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.rose.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.rose.withOpacity(0.3)),
                          ),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.close_rounded, size: 13, color: AppColors.rose),
                            SizedBox(width: 4),
                            Text('Bunk', style: TextStyle(color: AppColors.rose, fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      )),
                    ]),
                ]),
              ),
              ),
            ),
          ],
        );
      }),
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
