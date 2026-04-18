import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'timetable_provider.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  final String slotId;
  const AttendanceScreen({super.key, required this.slotId});
  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  String _status = 'present';
  bool _isLoading = false;
  final _today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(timetableProvider.notifier).markAttendance(widget.slotId, _today, _status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attendance marked: $_status'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final options = {
      'present': (Colors.green, Icons.check_circle_outline, 'Present'),
      'absent': (Colors.red, Icons.cancel_outlined, 'Absent'),
      'cancelled': (Colors.orange, Icons.event_busy_outlined, 'Cancelled'),
      'holiday': (Colors.blue, Icons.beach_access_outlined, 'Holiday'),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Mark Attendance')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Today — $_today', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            ...options.entries.map((e) {
              final (color, icon, label) = e.value;
              final selected = _status == e.key;
              return GestureDetector(
                onTap: () => setState(() => _status = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.15) : cs.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? color : Colors.transparent, width: 2),
                  ),
                  child: Row(children: [
                    Icon(icon, color: selected ? color : cs.outline),
                    const SizedBox(width: 14),
                    Text(label, style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                      color: selected ? color : null,
                      fontSize: 16,
                    )),
                    const Spacer(),
                    if (selected) Icon(Icons.check_circle, color: color),
                  ]),
                ),
              );
            }),
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
