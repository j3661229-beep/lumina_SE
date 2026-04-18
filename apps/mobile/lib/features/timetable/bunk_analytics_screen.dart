import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'timetable_provider.dart';

class BunkAnalyticsScreen extends ConsumerWidget {
  const BunkAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(bunkAnalyticsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Bunk Analytics')),
      body: analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.school_outlined, size: 64, color: cs.outline),
                const SizedBox(height: 12),
                Text('No attendance data yet', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Mark your first attendance to see analytics', style: TextStyle(color: cs.outline)),
              ]),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final item = data[i] as Map<String, dynamic>;
              final pct = (item['percentage'] as num?)?.toDouble() ?? 0.0;
              final attended = (item['attended'] as num?)?.toInt() ?? 0;
              final total = (item['total_held'] as num?)?.toInt() ?? 0;
              final bunksLeft = (item['bunks_remaining'] as num?)?.toInt() ?? 0;
              final safe = pct >= 75.0;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: safe
                      ? Colors.green.withOpacity(0.05)
                      : Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: safe ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(item['subject_name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: safe ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${pct.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 8,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(safe ? Colors.green : Colors.red),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    _Stat(label: 'Attended', value: '$attended/$total'),
                    const SizedBox(width: 16),
                    _Stat(
                      label: safe ? 'Can bunk' : 'Need to attend',
                      value: safe ? '$bunksLeft more' : 'ASAP',
                      color: safe ? Colors.green : Colors.red,
                    ),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
    Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
  ]);
}
