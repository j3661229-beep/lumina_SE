import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/shimmer_widgets.dart';
import 'timetable_provider.dart';

class BunkAnalyticsScreen extends ConsumerWidget {
  const BunkAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(bunkAnalyticsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(children: [
        // Ambient glow
        Positioned(
          top: -80, right: -80,
          child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.indigo.withOpacity(context.isDark ? 0.15 : 0.08), Colors.transparent,
              ]),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => context.go('/home'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Row(children: [
                        Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: Theme.of(context).colorScheme.onSurface),
                        const SizedBox(width: 6),
                        Text('Back', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  Text('Bunk Analytics',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
                  const SizedBox(width: 70),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: analyticsAsync.when(
                loading: () => const CardListShimmer(count: 6, cardHeight: 80),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: const TextStyle(color: AppColors.rose))),
                data: (data) {
                  if (data.isEmpty) {
                    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.indigo.withOpacity(context.isDark ? 0.15 : 0.08), 
                          shape: BoxShape.circle
                        ),
                        child: const Icon(Icons.school_outlined, size: 48, color: AppColors.indigo),
                      ),
                      const SizedBox(height: 16),
                      Text('No attendance data yet',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'Syne')),
                      const SizedBox(height: 6),
                      Text('Mark your first attendance to see analytics',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 13)),
                    ]));
                  }

                  // Summary stats
                  final items = data.map((e) => e as Map<String, dynamic>).toList();
                  final avgPct = items.map((e) => (e['percentage'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / items.length;
                  final safeCount = items.where((e) => ((e['percentage'] as num?)?.toDouble() ?? 0) >= 75.0).length;
                  final totalBunks = items.map((e) => (e['bunks_remaining'] as num?)?.toInt() ?? 0).where((b) => b > 0).fold<int>(0, (a, b) => a + b);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    children: [
                      // Summary card
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.indigo.withOpacity(0.15), AppColors.violet.withOpacity(0.08)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          _SummaryItem(label: 'Overall', value: '${avgPct.toStringAsFixed(1)}%', color: AppColors.green),
                          _SummaryItem(label: 'Safe Subjects', value: '$safeCount/${items.length}', color: AppColors.amber),
                          _SummaryItem(label: 'Bunks Left', value: '$totalBunks', color: AppColors.indigo),
                        ]),
                      ),

                      // Subject cards
                      ...items.map((item) {
                        final pct = (item['percentage'] as num?)?.toDouble() ?? 0.0;
                        final attended = (item['attended'] as num?)?.toInt() ?? 0;
                        final total = (item['total_held'] as num?)?.toInt() ?? 0;
                        final bunksLeft = (item['bunks_remaining'] as num?)?.toInt() ?? 0;
                        final safe = pct >= 75.0;
                        final statusColor = safe ? AppColors.green : AppColors.rose;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border(left: BorderSide(color: statusColor, width: 3)),
                            boxShadow: context.isDark ? [] : [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
                            ],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(item['subject_name'] ?? '',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'Syne')),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: statusColor.withOpacity(0.4)),
                                  ),
                                  child: Text('${pct.toStringAsFixed(1)}%',
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Progress bar
                            Stack(children: [
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: (pct / 100).clamp(0.0, 1.0),
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    gradient: LinearGradient(colors: [statusColor, statusColor.withOpacity(0.6)]),
                                  ),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              Icon(Icons.check_circle_outline_rounded, size: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                              const SizedBox(width: 5),
                              Text('Attended: $attended/$total',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 11)),
                              const Spacer(),
                              Text(
                                safe
                                  ? (bunksLeft > 0 ? 'Can bunk $bunksLeft more' : 'Borderline ⚠️')
                                  : 'Attend ASAP',
                                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ]),
                          ]),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w600)),
  ]);
}
