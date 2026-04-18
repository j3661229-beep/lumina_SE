import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/design_tokens.dart';
import 'timetable_provider.dart';

class BunkAnalyticsScreen extends ConsumerWidget {
  const BunkAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(bunkAnalyticsProvider);

    return Scaffold(
      backgroundColor: DesignColor.bg,
      body: Stack(children: [
        // Ambient glow
        Positioned(
          top: -80, right: -80,
          child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                DesignColor.indigo.withOpacity(0.15), Colors.transparent,
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
                        color: DesignColor.s1,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: DesignColor.border),
                      ),
                      child: const Row(children: [
                        Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: DesignColor.text),
                        SizedBox(width: 6),
                        Text('Back', style: TextStyle(color: DesignColor.text, fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  const Text('Bunk Analytics',
                    style: TextStyle(color: DesignColor.text, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
                  const SizedBox(width: 70),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: analyticsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: DesignColor.indigo)),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: const TextStyle(color: DesignColor.rose))),
                data: (data) {
                  if (data.isEmpty) {
                    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(color: DesignColor.indigoGlow, shape: BoxShape.circle),
                        child: const Icon(Icons.school_outlined, size: 48, color: DesignColor.indigo),
                      ),
                      const SizedBox(height: 16),
                      const Text('No attendance data yet',
                        style: TextStyle(color: DesignColor.text, fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'Syne')),
                      const SizedBox(height: 6),
                      const Text('Mark your first attendance to see analytics',
                        style: TextStyle(color: DesignColor.sub, fontSize: 13)),
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
                            colors: [DesignColor.indigo.withOpacity(0.15), DesignColor.violet.withOpacity(0.08)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: DesignColor.borderH),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          _SummaryItem(label: 'Overall', value: '${avgPct.toStringAsFixed(1)}%', color: DesignColor.green),
                          _SummaryItem(label: 'Safe Subjects', value: '$safeCount/${items.length}', color: DesignColor.amber),
                          _SummaryItem(label: 'Bunks Left', value: '$totalBunks', color: DesignColor.indigo),
                        ]),
                      ),

                      // Subject cards
                      ...items.map((item) {
                        final pct = (item['percentage'] as num?)?.toDouble() ?? 0.0;
                        final attended = (item['attended'] as num?)?.toInt() ?? 0;
                        final total = (item['total_held'] as num?)?.toInt() ?? 0;
                        final bunksLeft = (item['bunks_remaining'] as num?)?.toInt() ?? 0;
                        final safe = pct >= 75.0;
                        final statusColor = safe ? DesignColor.green : DesignColor.rose;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: DesignColor.s1,
                            borderRadius: BorderRadius.circular(16),
                            border: Border(left: BorderSide(color: statusColor, width: 3)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(item['subject_name'] ?? '',
                                    style: const TextStyle(color: DesignColor.text, fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'Syne')),
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
                                  color: DesignColor.s2,
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
                              const Icon(Icons.check_circle_outline_rounded, size: 13, color: DesignColor.sub),
                              const SizedBox(width: 5),
                              Text('Attended: $attended/$total',
                                style: const TextStyle(color: DesignColor.sub, fontSize: 11)),
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
    Text(label, style: const TextStyle(color: DesignColor.muted, fontSize: 10, fontWeight: FontWeight.w600)),
  ]);
}
