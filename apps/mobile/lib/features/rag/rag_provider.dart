import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'vector_store.dart';
import 'gemini_rag_service.dart'; // kept for synthesise()

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

    state = AsyncData(state.value!.copyWith(
      isIndexing: true,
      indexProgress: 0,
      indexingStatus: '📄 Extracting text from ${file.name}…',
    ));

    try {
      String rawText = '';

      if (file.extension?.toLowerCase() == 'pdf') {
        rawText = await _extractPdfText(file.path ?? '');
      } else {
        rawText = File(file.path!).readAsStringSync();
      }

      if (rawText.trim().isEmpty) {
        state = AsyncData(state.value!.copyWith(
          isIndexing: false,
          indexingStatus: '⚠️ Could not extract text. Is the PDF scanned/image-only?',
        ));
        return;
      }

      // ── Chunk text ──────────────────────────────────────────────────────
      final chunks = _chunkText(rawText, chunkSize: 400, overlap: 80);
      debugPrint('[RAG] ${file.name}: ${rawText.length} chars → ${chunks.length} chunks');

      if (chunks.isEmpty) {
        state = AsyncData(state.value!.copyWith(
          isIndexing: false,
          indexingStatus: '⚠️ Document produced no usable text chunks.',
        ));
        return;
      }

      state = AsyncData(state.value!.copyWith(
        indexingStatus: '⚡ Embedding ${chunks.length} chunks on-device…',
      ));

      // Use filename as deterministic docId so re-uploads replace old chunks
      final docId = file.name;
      // Always delete old chunks for this file first (prevents mixed-vector accumulation)
      await VectorStore.instance.deleteDoc(docId);
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
    for (int i = 0; i < chunks.length; i += 10) {
      final end = (i + 10).clamp(0, chunks.length);
      final batch = chunks.sublist(i, end);

      await VectorStore.instance.addChunksBatch(docId, docTitle, batch, docType, startIndex: i);

      final progress = end / chunks.length;
      state = AsyncData(state.value!.copyWith(
        isIndexing: true,
        indexProgress: progress,
        indexingStatus: '⚡ Indexed $end / ${chunks.length} chunks…',
      ));
    }
  }

  // ── Delete a document ─────────────────────────────────────────────────────
  Future<void> deleteDoc(String docId) async {
    await VectorStore.instance.deleteDoc(docId);
    state = AsyncData(await _buildState());
  }

  // ── Clear everything (use after embedding schema changes) ─────────────────
  Future<void> clearAllDocs() async {
    await VectorStore.instance.clearAll();
    state = AsyncData(await _buildState());
  }

  // ── Semantic search → synthesis ───────────────────────────────────────────
  Future<String> query(String q) async {
    final chunks = await VectorStore.instance.search(q, topK: 5);
    if (chunks.isEmpty) {
      return 'No relevant content found in your documents. Try uploading some PDFs first.';
    }
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

  // ── Chunker ────────────────────────────────────────────────────────────────
  // Root issue: Syncfusion extracts PDFs with single \n for line-wraps (no blank lines).
  // Attempting to split on \n\n produces only 1-2 "paragraphs" = 2 huge chunks.
  // Fix: ALWAYS flatten ALL newlines into spaces → single clean line → slide window.
  static List<String> _chunkText(String text, {int chunkSize = 400, int overlap = 80}) {
    // Flatten: PDF \n = line-wrap (not paragraph). Collapse everything to spaces.
    final flat = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\n', ' ')            // ALL newlines → space
        .replaceAll(RegExp(r'\s+'), ' ')  // collapse whitespace runs
        .trim();

    debugPrint('[RAG] Flattened to ${flat.length} chars');
    if (flat.length <= 30) return [];

    return _charSlidingWindow(flat, chunkSize, overlap);
  }

  // Character sliding window that snaps to word boundaries
  static List<String> _charSlidingWindow(String text, int size, int overlap) {
    final chunks = <String>[];
    int i = 0;
    while (i < text.length) {
      int end = (i + size).clamp(0, text.length);
      // Snap forward to next word boundary so we don't cut mid-word
      if (end < text.length) {
        final spaceAfter = text.indexOf(' ', end);
        if (spaceAfter != -1 && spaceAfter - end < 60) end = spaceAfter;
      }
      final chunk = text.substring(i, end).trim();
      if (chunk.length > 30) chunks.add(chunk);
      if (end >= text.length) break;
      i += size - overlap;
    }
    return chunks;
  }
}
