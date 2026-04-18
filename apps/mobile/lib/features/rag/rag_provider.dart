import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'vector_store.dart';
import 'gemini_rag_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────
class RagState {
  final bool isIndexing;
  final double indexProgress;        // 0.0 – 1.0
  final String? indexingStatus;
  final List<({String docId, String docTitle, String docType, int chunks, DateTime addedAt})> docs;
  final int totalChunks;

  const RagState({
    this.isIndexing = false,
    this.indexProgress = 0,
    this.indexingStatus,
    this.docs = const [],
    this.totalChunks = 0,
  });

  RagState copyWith({
    bool? isIndexing,
    double? indexProgress,
    String? indexingStatus,
    List<({String docId, String docTitle, String docType, int chunks, DateTime addedAt})>? docs,
    int? totalChunks,
  }) => RagState(
    isIndexing: isIndexing ?? this.isIndexing,
    indexProgress: indexProgress ?? this.indexProgress,
    indexingStatus: indexingStatus ?? this.indexingStatus,
    docs: docs ?? this.docs,
    totalChunks: totalChunks ?? this.totalChunks,
  );
}

// ── Provider ──────────────────────────────────────────────────────────────────
final ragProvider = AsyncNotifierProvider<RagNotifier, RagState>(RagNotifier.new);

class RagNotifier extends AsyncNotifier<RagState> {
  @override
  Future<RagState> build() async {
    await VectorStore.instance.init();
    return _buildState();
  }

  Future<RagState> _buildState() async {
    final docs = await VectorStore.instance.listDocs();
    final count = await VectorStore.instance.totalChunks;
    return RagState(docs: docs, totalChunks: count);
  }

  // ── Pick & Index a PDF or TXT ─────────────────────────────────────────────
  Future<void> pickAndIndex() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final online = await GeminiRagService.instance.isOnline();

    state = AsyncData(state.value!.copyWith(
      isIndexing: true,
      indexProgress: 0,
      indexingStatus: online
          ? 'Extracting text…'
          : 'Offline — using fast local embeddings…',
    ));

    try {
      String rawText = '';

      if (file.extension?.toLowerCase() == 'pdf') {
        rawText = await _extractPdfText(file.path ?? '');
      } else {
        // Plain text
        rawText = File(file.path!).readAsStringSync();
      }

      if (rawText.trim().isEmpty) {
        state = AsyncData(state.value!.copyWith(
          isIndexing: false,
          indexingStatus: '⚠️ Could not extract text. Is the PDF scanned/image-only?',
        ));
        return;
      }

      // ── Chunk text (sliding window, ~400 chars with 80-char overlap) ──────
      final chunks = _chunkText(rawText, chunkSize: 400, overlap: 80);
      debugPrint('[RAG] ${file.name}: ${rawText.length} chars → ${chunks.length} chunks');

      state = AsyncData(state.value!.copyWith(indexingStatus: 'Generating embeddings (${chunks.length} chunks)…'));

      // ── Index in VectorStore with progress updates ────────────────────────
      final docId = '${file.name}_${DateTime.now().millisecondsSinceEpoch}';

      // Override addChunks to report progress
      await _indexWithProgress(docId, file.name, chunks, file.extension ?? 'doc');

      state = AsyncData(await _buildState());
    } catch (e, st) {
      debugPrint('[RAG] Indexing error: $e\n$st');
      state = AsyncData(state.value!.copyWith(
        isIndexing: false,
        indexingStatus: '⚠️ Error: $e',
      ));
    }
  }

  Future<void> _indexWithProgress(
    String docId, String docTitle, List<String> chunks, String docType) async {
    // Use the public VectorStore API — it handles embedding internally
    for (int i = 0; i < chunks.length; i += 10) {
      // Process in batches of 10 for progress reporting
      final end = (i + 10).clamp(0, chunks.length);
      final batch = chunks.sublist(i, end);

      await VectorStore.instance.addChunksBatch(docId, docTitle, batch, docType, startIndex: i);

      final progress = end / chunks.length;
      state = AsyncData(state.value!.copyWith(
        isIndexing: true,
        indexProgress: progress,
        indexingStatus: 'Embedding chunk $end/${chunks.length}…',
      ));
    }
  }

  // ── Delete a document ─────────────────────────────────────────────────────
  Future<void> deleteDoc(String docId) async {
    await VectorStore.instance.deleteDoc(docId);
    state = AsyncData(await _buildState());
  }

  // ── Semantic search → Gemini synthesis ───────────────────────────────────
  Future<String> query(String q) async {
    final chunks = await VectorStore.instance.search(q, topK: 5);
    if (chunks.isEmpty) return 'No relevant content found in your documents. Try uploading some PDFs first.';
    final texts = chunks.map((c) => c.chunkText).toList();
    return await GeminiRagService.instance.synthesise(q, texts);
  }

  Future<List<Map<String, dynamic>>> search(String q) async {
    final chunks = await VectorStore.instance.search(q, topK: 5);
    return chunks.map((c) => {
      'docId': c.docId,
      'docTitle': c.docTitle,
      'chunkText': c.chunkText,
      'docType': c.docType,
    }).toList();
  }

  // ── PDF text extraction using Syncfusion ─────────────────────────────────
  static Future<String> _extractPdfText(String path) async {
    if (path.isEmpty) return '';
    try {
      final bytes = await File(path).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();
      return text;
    } catch (e) {
      debugPrint('[RAG] PDF Extraction Error: $e');
      return '';
    }
  }

  // ── Sliding window text chunker ───────────────────────────────────────────
  static List<String> _chunkText(String text, {int chunkSize = 400, int overlap = 80}) {
    // First split by paragraphs for better context
    final paras = text.split(RegExp(r'\n\s*\n')).where((p) => p.trim().length > 20).toList();

    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final para in paras) {
      final cleaned = para.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (buffer.length + cleaned.length < chunkSize) {
        buffer.write('$cleaned ');
      } else {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString().trim());
        }
        // Handle paragraphs longer than chunkSize
        if (cleaned.length > chunkSize) {
          for (int i = 0; i < cleaned.length; i += (chunkSize - overlap)) {
            final end = (i + chunkSize).clamp(0, cleaned.length);
            chunks.add(cleaned.substring(i, end));
            if (end >= cleaned.length) break;
          }
          buffer.clear();
        } else {
          buffer.clear();
          buffer.write('$cleaned ');
        }
      }
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString().trim());

    return chunks.where((c) => c.length > 30).toList();
  }
}
