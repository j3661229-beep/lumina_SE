import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfx/pdfx.dart';
import 'timetable_provider.dart';

class OcrParserScreen extends ConsumerStatefulWidget {
  const OcrParserScreen({super.key});
  @override
  ConsumerState<OcrParserScreen> createState() => _OcrParserScreenState();
}

class _OcrParserScreenState extends ConsumerState<OcrParserScreen> {
  bool _isProcessing = false;
  List<ParsedSlot> _parsedSlots = [];

  static const Map<String, List<String>> _dayAliases = {
    'monday': ['mon', 'monday'],
    'tuesday': ['tue', 'tuesday'],
    'wednesday': ['wed', 'wednesday'],
    'thursday': ['thu', 'thursday'],
    'friday': ['fri', 'friday'],
    'saturday': ['sat', 'saturday'],
  };

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

      String extractedText = '';

      if (choice == 'pdf') {
        final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
        if (result == null) { setState(() => _isProcessing = false); return; }
        extractedText = await _extractTextFromPdf(result.files.first.path!);
      } else {
        final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
        final img = await ImagePicker().pickImage(source: source, imageQuality: 90);
        if (img == null) { setState(() => _isProcessing = false); return; }
        extractedText = await _ocrImage(img.path);
      }

      final slots = _parseText(extractedText);
      setState(() { _parsedSlots = slots; _isProcessing = false; });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<String> _ocrImage(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognized = await recognizer.processImage(InputImage.fromFilePath(path));
    await recognizer.close();
    return recognized.text;
  }

  Future<String> _extractTextFromPdf(String path) async {
    final document = await PdfDocument.openFile(path);
    final buffer = StringBuffer();
    for (int i = 1; i <= document.pagesCount; i++) {
      final page = await document.getPage(i);
      final img = await page.render(width: page.width * 2, height: page.height * 2);
      final file = File('${Directory.systemTemp.path}/lumina_page_$i.png');
      await file.writeAsBytes(img!.bytes);
      buffer.write(await _ocrImage(file.path));
      await page.close();
    }
    await document.close();
    return buffer.toString();
  }

  List<ParsedSlot> _parseText(String text) {
    final slots = <ParsedSlot>[];
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    String currentDay = 'monday';
    final timeRegex = RegExp(r'(\d{1,2})[:.h](\d{2})\s*[-–to]+\s*(\d{1,2})[:.h](\d{2})');

    for (final line in lines) {
      final lower = line.toLowerCase();
      for (final entry in _dayAliases.entries) {
        if (entry.value.any((alias) => lower.contains(alias))) {
          currentDay = entry.key;
          break;
        }
      }
      final timeMatch = timeRegex.firstMatch(line);
      if (timeMatch == null) continue;

      final startH = int.parse(timeMatch.group(1)!).clamp(7, 20);
      final startM = int.parse(timeMatch.group(2)!).clamp(0, 59);
      final endH = int.parse(timeMatch.group(3)!).clamp(7, 20);
      final endM = int.parse(timeMatch.group(4)!).clamp(0, 59);

      final rest = line.substring(timeMatch.end).replaceAll(RegExp(r'[|/\\]'), '').trim();
      if (rest.isEmpty || rest.length > 60) continue;

      final slotType = rest.toLowerCase().contains('lab')
          ? 'lab'
          : rest.toLowerCase().contains('tutorial')
              ? 'tutorial'
              : 'lecture';

      slots.add(ParsedSlot(
        subjectName: rest,
        dayOfWeek: currentDay,
        startTime: '${startH.toString().padLeft(2, '0')}:${startM.toString().padLeft(2, '0')}',
        endTime: '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}',
        slotType: slotType,
      ));
    }
    return slots;
  }

  Future<void> _uploadTimetable() async {
    if (_parsedSlots.isEmpty) return;
    setState(() => _isProcessing = true);
    await ref.read(timetableProvider.notifier).uploadSlots(_parsedSlots);
    setState(() => _isProcessing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Timetable uploaded!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Import Timetable')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instruction card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cs.primaryContainer, cs.secondaryContainer]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                const Icon(Icons.tips_and_updates_outlined, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  'Take a photo of your timetable or upload a PDF. Lumina will auto-extract all slots.',
                  style: TextStyle(color: cs.onPrimaryContainer),
                )),
              ]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _pickAndParse,
              icon: const Icon(Icons.document_scanner),
              label: const Text('Scan Timetable'),
            ),
            const SizedBox(height: 16),
            if (_isProcessing) const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Processing...'),
              ]),
            )),
            if (_parsedSlots.isNotEmpty) ...[
              Row(children: [
                Text('${_parsedSlots.length} slots found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _parsedSlots = []),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
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
                        color: cs.errorContainer,
                        child: Icon(Icons.delete, color: cs.error),
                      ),
                      onDismissed: (_) => setState(() => _parsedSlots.removeAt(i)),
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cs.primaryContainer,
                            child: Text(s.dayOfWeek.substring(0, 3).toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                          title: Text(s.subjectName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${s.startTime} – ${s.endTime}  •  ${s.slotType}'),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _uploadTimetable,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text('Upload ${_parsedSlots.length} Slots'),
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
  const ParsedSlot({
    required this.subjectName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.slotType,
  });
  Map<String, dynamic> toJson() => {
    'subject_name': subjectName,
    'day_of_week': dayOfWeek,
    'start_time': startTime,
    'end_time': endTime,
    'slot_type': slotType,
  };
}
