import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/design_tokens.dart';
import 'timetable_provider.dart';
import 'timetable_models.dart';

class OcrParserScreen extends ConsumerStatefulWidget {
  const OcrParserScreen({super.key});
  @override
  ConsumerState<OcrParserScreen> createState() => _OcrParserScreenState();
}

class _OcrParserScreenState extends ConsumerState<OcrParserScreen> {
  bool _isProcessing = false;
  List<ParsedSlot> _parsedSlots = [];
  List<ParsedHoliday> _parsedHolidays = [];
  DateTime? _semStart;
  DateTime? _semEnd;

  Future<void> _pickAndParse({bool isHolidayOnly = false}) async {
    setState(() => _isProcessing = true);
    try {
      final choice = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, 'camera')),
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery')),
            ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const Text('Upload PDF'),
              onTap: () => Navigator.pop(ctx, 'pdf')),
          ]),
        ),
      );

      if (choice == null) { setState(() => _isProcessing = false); return; }

      String filePath = '';

      if (choice == 'pdf') {
        final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
        if (result == null || result.files.isEmpty) { setState(() => _isProcessing = false); return; }
        filePath = result.files.first.path!;
      } else if (choice == 'gallery') {
        final result = await FilePicker.platform.pickFiles(type: FileType.image);
        if (result == null || result.files.isEmpty) { setState(() => _isProcessing = false); return; }
        filePath = result.files.first.path!;
      } else {
        final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
        if (img == null) { setState(() => _isProcessing = false); return; }
        filePath = img.path;
      }

      final result = await ref.read(timetableProvider.notifier).uploadTimetableImage(filePath);
      
      if (result.slots.isEmpty && result.holidays.isEmpty && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('No data found in image. Make sure the timetable is clear.')),
         );
       }
      
      setState(() { 
        if (isHolidayOnly) {
          // Merge holidays, keep current slots
          _parsedHolidays = [..._parsedHolidays, ...result.holidays];
        } else {
          // Replace slots, and take holidays if found
          _parsedSlots = result.slots; 
          _parsedHolidays = result.holidays;
        }
        _isProcessing = false; 
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        String msg = e.toString();
        if (e is DioException) {
          if (e.response?.data is Map && e.response?.data['error'] != null) {
            msg = e.response?.data['error']?.toString() ?? msg;
          } else {
            msg = e.message ?? msg;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $msg'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  // Gemini handles extraction seamlessly now.

  Future<void> _uploadTimetable() async {
    if (_parsedSlots.isEmpty && _parsedHolidays.isEmpty) return;
    setState(() => _isProcessing = true);
    await ref.read(timetableProvider.notifier).uploadSlots(
      slots: _parsedSlots,
      holidays: _parsedHolidays,
      semesterStart: _semStart,
      semesterEnd: _semEnd,
    );
    setState(() => _isProcessing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Timetable uploaded!')),
      );
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Import Timetable',
          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => context.go('/home'),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instruction card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0x1A6366F1), Color(0x14A78BFA)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(children: [
                const Icon(Icons.tips_and_updates_outlined, size: 28, color: AppColors.indigo),
                SizedBox(width: 12),
                Expanded(child: Text(
                  'Take a photo of your timetable or upload a PDF. Gemini AI will auto-extract all slots.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 13, height: 1.5),
                )),
              ]),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: DesignStyles.gradientButton(),
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickAndParse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.document_scanner),
                label: const Text('Scan Timetable', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 16),
            if (_isProcessing) Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const CircularProgressIndicator(color: AppColors.indigo),
                const SizedBox(height: 14),
                Text('Gemini is analysing your timetable...', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
              ]),
            )),
            if (_parsedSlots.isNotEmpty || _parsedHolidays.isNotEmpty) ...[
              // ── Academic Year Setup ─────────────────────────────
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppStyles.glassCard(context),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Semester Duration', style: TextStyle(
                    fontFamily: 'Syne', fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _DateTile(
                      label: 'Starts', 
                      date: _semStart, 
                      onTap: () async {
                        final d = await showDatePicker(context: context, 
                          initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (d != null) setState(() => _semStart = d);
                      }
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _DateTile(
                      label: 'Ends', 
                      date: _semEnd, 
                      onTap: () async {
                        final d = await showDatePicker(context: context, 
                          initialDate: DateTime.now().add(const Duration(days: 90)), firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (d != null) setState(() => _semEnd = d);
                      }
                    )),
                  ]),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Text('Holiday Calendar', style: TextStyle(
                    fontFamily: 'Syne', fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text('Upload a separate image for college holidays if your timetable doesn\'t include them.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : () => _pickAndParse(isHolidayOnly: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.indigo,
                        side: BorderSide(color: AppColors.indigo.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.beach_access_outlined, size: 18),
                      label: const Text('Scan Calendar for Holidays', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Slots & Holidays ────────────────────────────────
              Row(children: [
                Text('Detected Items',
                  style: TextStyle(
                    fontFamily: 'Syne', fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() { _parsedSlots = []; _parsedHolidays = []; }),
                  icon: const Icon(Icons.clear, size: 14, color: AppColors.rose),
                  label: const Text('Clear All', style: TextStyle(color: AppColors.rose)),
                ),
              ]),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    if (_parsedSlots.isNotEmpty) ...[
                      const _SectionHeader(label: 'Classes'),
                      ..._parsedSlots.asMap().entries.map((e) => _buildSlotTile(e.key, e.value)),
                    ],
                    if (_parsedHolidays.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _SectionHeader(label: 'Holidays'),
                      ..._parsedHolidays.asMap().entries.map((e) => _buildHolidayTile(e.key, e.value)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: DesignStyles.gradientButton(),
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _uploadTimetable,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text('Save Timetable', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSlotTile(int index, ParsedSlot s) {
    return Dismissible(
      key: ValueKey('slot_$index'),
      direction: DismissDirection.endToStart,
      background: _buildDismissBg(),
      onDismissed: (_) => setState(() => _parsedSlots.removeAt(index)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: AppStyles.glassCard(context),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.indigo.withOpacity(0.15),
            child: Text(s.dayOfWeek.substring(0, 3).toUpperCase(),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.indigo)),
          ),
          title: Text(s.subjectName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${s.startTime} – ${s.endTime}  •  ${s.slotType}${s.teacher != null ? ' • ${s.teacher}' : ''}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildHolidayTile(int index, ParsedHoliday h) {
    return Dismissible(
      key: ValueKey('holiday_$index'),
      direction: DismissDirection.endToStart,
      background: _buildDismissBg(),
      onDismissed: (_) => setState(() => _parsedHolidays.removeAt(index)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: AppStyles.glassCard(context),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.amber.withOpacity(0.15),
            child: const Icon(Icons.event_available_outlined, size: 14, color: AppColors.amber),
          ),
          title: Text(h.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
          subtitle: Text(h.date,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildDismissBg() => Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 16),
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(color: AppColors.rose.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
    child: const Icon(Icons.delete, color: AppColors.rose),
  );
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(label.toUpperCase(), style: TextStyle(
      fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2,
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
  );
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateTile({required this.label, required this.onTap, this.date});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = date != null ? '${date!.day}/${date!.month}/${date!.year}' : 'Select';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.onSurface.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.onSurface.withOpacity(0.08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: cs.onSurface.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(dateStr, style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ParsedSlot, ParsedHoliday, OcrResult moved to timetable_models.dart
