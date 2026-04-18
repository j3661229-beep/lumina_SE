import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'vector_store.dart';

final ragProvider = AsyncNotifierProvider<RagNotifier, void>(RagNotifier.new);

class RagNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    await VectorStore.instance.init();
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    final results = await VectorStore.instance.search(query);
    return results.map((r) => {
      'docId': r.docId,
      'docTitle': r.docTitle,
      'chunkText': r.chunkText,
      'docType': r.docType,
    }).toList();
  }

  Future<void> pickAndIndex() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
    );
    if (result == null) return;

    state = const AsyncLoading();
    try {
      final file = result.files.first;
      String text = '';

      if (file.extension == 'txt') {
        final bytes = file.bytes ?? <int>[];
        text = String.fromCharCodes(bytes);
      } else {
        // OCR the PDF
        final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
        text = file.path ?? '';
        await recognizer.close();
      }

      // Chunk by ~200 chars
      final chunks = <String>[];
      for (int i = 0; i < text.length; i += 200) {
        final end = i + 200 < text.length ? i + 200 : text.length;
        chunks.add(text.substring(i, end).trim());
      }
      final filtered = chunks.where((c) => c.length > 20).toList();

      await VectorStore.instance.addChunks(
        DateTime.now().millisecondsSinceEpoch.toString(),
        file.name,
        filtered,
        file.extension ?? 'doc',
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
