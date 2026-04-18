import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/design_tokens.dart';
import 'timetable_provider.dart';

class OcrParserScreen extends ConsumerStatefulWidget {
  const OcrParserScreen({super.key});
  @override
  ConsumerState<OcrParserScreen> createState() => _OcrParserScreenState();
}

class _OcrParserScreenState extends ConsumerState<OcrParserScreen> {
  bool _isProcessing = false;
  List<ParsedSlot> _parsedSlots = [];

  Future<void> _pickAndParse() async {
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

      final slots = await ref.read(timetableProvider.notifier).uploadTimetableImage(filePath);
      
      if (slots.isEmpty && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('No classes found in image. Make sure the timetable is clear.')),
         );
      }
      
      setState(() { _parsedSlots = slots; _isProcessing = false; });
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
    if (_parsedSlots.isEmpty) return;
    setState(() => _isProcessing = true);
    await ref.read(timetableProvider.notifier).uploadSlots(_parsedSlots);
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
            if (_parsedSlots.isNotEmpty) ...[
              Row(children: [
                Text('${_parsedSlots.length} slots found',
                  style: TextStyle(
                    fontFamily: 'Syne', fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _parsedSlots = []),
                  icon: const Icon(Icons.clear, size: 14, color: AppColors.rose),
                  label: const Text('Clear', style: TextStyle(color: AppColors.rose)),
                ),
              ]),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _parsedSlots.length,
                  itemBuilder: (ctx, i) {
                    final s = _parsedSlots[i];
                    return Dismissible(
                      key: ValueKey(i),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: AppColors.rose.withOpacity(0.1),
                        child: const Icon(Icons.delete, color: AppColors.rose),
                      ),
                      onDismissed: (_) => setState(() => _parsedSlots.removeAt(i)),
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
                  },
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
                  label: Text('Save ${_parsedSlots.length} Slots', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ParsedSlot {
  final String subjectName, dayOfWeek, startTime, endTime, slotType;
  final String? teacher;
  
  const ParsedSlot({
    required this.subjectName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.slotType,
    this.teacher,
  });
  Map<String, dynamic> toJson() => {
    'subject_name': subjectName,
    'day_of_week': dayOfWeek,
    'start_time': startTime,
    'end_time': endTime,
    'slot_type': slotType,
    if (teacher != null) 'teacher': teacher,
  };
}
