import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/design_tokens.dart';
import 'timetable_provider.dart';

void showEditSlotSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> slot) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _EditSlotSheet(slot: slot, ref: ref),
  );
}

class _EditSlotSheet extends StatefulWidget {
  final Map<String, dynamic> slot;
  final WidgetRef ref;
  const _EditSlotSheet({required this.slot, required this.ref});

  @override
  State<_EditSlotSheet> createState() => _EditSlotSheetState();
}

class _EditSlotSheetState extends State<_EditSlotSheet> {
  late TextEditingController _subjectCtrl;
  late TextEditingController _roomCtrl;
  late String _dayOfWeek;
  late String _startTime;
  late String _endTime;
  late String _slotType;

  @override
  void initState() {
    super.initState();
    final subject = widget.slot['subject'] as Map<String, dynamic>? ?? {};
    _subjectCtrl = TextEditingController(text: subject['name'] ?? '');
    _roomCtrl = TextEditingController(text: widget.slot['room'] ?? '');
    _dayOfWeek = widget.slot['day_of_week'] ?? 'monday';
    _startTime = widget.slot['start_time'] ?? '09:00';
    _endTime = widget.slot['end_time'] ?? '10:00';
    _slotType = widget.slot['slot_type'] ?? 'lecture';
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final curParams = (isStart ? _startTime : _endTime).split(':');
    final curTime = TimeOfDay(hour: int.parse(curParams[0]), minute: int.parse(curParams[1]));
    
    final picked = await showTimePicker(
      context: context,
      initialTime: curTime,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: DesignColor.indigo,
            surface: Color(0xFF0F1228),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) _startTime = formatted; else _endTime = formatted;
      });
    }
  }

  // _pickAttendanceDate removed because user requested inline horizontal week array

  Future<void> _markAttendance(String status) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await widget.ref.read(timetableProvider.notifier).markAttendance(
        widget.slot['id'], dateStr, status
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'present' ? '✅ Marked present for today' : '🚫 Marked absent for today'),
          backgroundColor: status == 'present' ? AppColors.green : AppColors.rose,
        ));
      }
    } catch (e) {
      debugPrint('[EditSlotSheet] Mark attendance failed: $e');
    }
  }

  Future<void> _saveSlot() async {
    final notifier = widget.ref.read(timetableProvider.notifier);
    await notifier.updateSlot(widget.slot['id'], {
      'subject_name': _subjectCtrl.text.trim(),
      'day_of_week': _dayOfWeek,
      'start_time': _startTime,
      'end_time': _endTime,
      'room': _roomCtrl.text.trim(),
      'slot_type': _slotType,
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteSlot() async {
    final notifier = widget.ref.read(timetableProvider.notifier);
    await notifier.deleteIndividualSlot(widget.slot['id']);
    if (mounted) Navigator.pop(context);
  }

  InputDecoration _deco(String label, BuildContext context) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: AppColors.textSecondary(context)),
    filled: true,
    fillColor: AppColors.surface(context),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border(context))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.indigo)),
  );

  @override
  Widget build(BuildContext context) {
    final logs = widget.ref.watch(attendanceLogsProvider).value ?? {};
    final currentStatus = logs['${widget.slot['id']}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}'];

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border(context))),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border(context), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Timetable Slot', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Syne')),
                IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.rose), onPressed: _deleteSlot),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _subjectCtrl, style: TextStyle(color: AppColors.textPrimary(context)),
              decoration: _deco('Subject Name', context),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _roomCtrl, style: TextStyle(color: AppColors.textPrimary(context)), decoration: _deco('Room (Optional)', context))),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(
                value: _slotType, dropdownColor: AppColors.surface(context), style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: _deco('Record Type', context),
                items: ['lecture', 'lab', 'tutorial'].map((e) => DropdownMenuItem(value: e, child: Text(e[0].toUpperCase() + e.substring(1)))).toList(),
                onChanged: (v) => setState(() => _slotType = v!),
              )),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _dayOfWeek, dropdownColor: AppColors.surface(context), style: TextStyle(color: AppColors.textPrimary(context)),
              decoration: _deco('Day of Week', context),
              items: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'].map((e) => DropdownMenuItem(value: e, child: Text(e[0].toUpperCase() + e.substring(1)))).toList(),
              onChanged: (v) => setState(() => _dayOfWeek = v!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => _pickTime(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border(context))),
                  child: Row(children: [
                    Icon(Icons.access_time, size: 16, color: AppColors.textSecondary(context)), const SizedBox(width: 8),
                    Text(_startTime, style: TextStyle(color: AppColors.textPrimary(context))),
                  ]),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => _pickTime(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border(context))),
                  child: Row(children: [
                    Icon(Icons.access_time_filled, size: 16, color: AppColors.textSecondary(context)), const SizedBox(width: 8),
                    Text(_endTime, style: TextStyle(color: AppColors.textPrimary(context))),
                  ]),
                ),
              )),
            ]),
            const SizedBox(height: 24),
            Divider(color: AppColors.border(context)),
            const SizedBox(height: 16),
            Text('Mark Attendance (Today)', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Syne')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _markAttendance('present'),
                  style: FilledButton.styleFrom(
                    backgroundColor: currentStatus == 'present' ? AppColors.green : AppColors.green.withOpacity(0.12),
                    foregroundColor: currentStatus == 'present' ? Colors.white : AppColors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Present'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _markAttendance('absent'),
                  style: FilledButton.styleFrom(
                    backgroundColor: currentStatus == 'absent' ? AppColors.rose : AppColors.rose.withOpacity(0.12),
                    foregroundColor: currentStatus == 'absent' ? Colors.white : AppColors.rose,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Absent'),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: DesignStyles.gradientButton(),
                child: FilledButton(
                  onPressed: _saveSlot,
                  style: FilledButton.styleFrom(backgroundColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
