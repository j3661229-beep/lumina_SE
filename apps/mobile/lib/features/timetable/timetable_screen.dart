import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'timetable_provider.dart';

class TimetableScreen extends ConsumerWidget {
  const TimetableScreen({super.key});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _daysFull = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(timetableProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Timetable'),
        actions: [
          IconButton(
            tooltip: 'Import via OCR',
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: () => context.go('/ocr'),
          ),
          IconButton(
            tooltip: 'Bunk Analytics',
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => context.go('/bunk'),
          ),
        ],
      ),
      body: slotsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (slots) {
          final grouped = <String, List<dynamic>>{
            for (final d in _daysFull) d: [],
          };
          for (final slot in slots) {
            final day = slot['day_of_week'] as String? ?? '';
            grouped[day]?.add(slot);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _days.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final day = _daysFull[i];
              final daySlots = grouped[day] ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(_days[i],
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: cs.onPrimaryContainer,
                          )),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${daySlots.length} classes',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline)),
                  ]),
                  const SizedBox(height: 8),
                  if (daySlots.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(Icons.free_breakfast_outlined, color: cs.outline, size: 18),
                        const SizedBox(width: 8),
                        Text('Free day 🎉', style: TextStyle(color: cs.outline)),
                      ]),
                    )
                  else
                    ...daySlots.map((slot) => _SlotCard(slot: slot)),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/ocr'),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Import'),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final dynamic slot;
  const _SlotCard({required this.slot});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subject = slot['subject'] as Map<String, dynamic>? ?? {};
    final colorHex = subject['color_hex'] as String? ?? '#6366F1';
    final color = Color(int.parse(colorHex.replaceFirst('#', 'FF'), radix: 16));
    final slotType = slot['slot_type'] as String? ?? 'lecture';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 48, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(subject['name'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.access_time_outlined, size: 13, color: cs.outline),
                const SizedBox(width: 4),
                Text('${slot['start_time']} – ${slot['end_time']}',
                  style: TextStyle(fontSize: 12, color: cs.outline)),
                if (slot['room'] != null) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.room_outlined, size: 13, color: cs.outline),
                  const SizedBox(width: 2),
                  Text(slot['room'], style: TextStyle(fontSize: 12, color: cs.outline)),
                ],
              ]),
            ]),
          ),
          Chip(
            label: Text(slotType, style: const TextStyle(fontSize: 11)),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            backgroundColor: color.withOpacity(0.15),
            side: BorderSide.none,
          ),
        ],
      ),
    );
  }
}
