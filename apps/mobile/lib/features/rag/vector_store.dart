import 'dart:math';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'gemini_rag_service.dart';

part 'vector_store.g.dart';

/// A persisted document chunk with its 768-dim Gemini embedding.
/// Falls back to 384-dim hash-based embedding when offline.
@collection
class DocumentChunk {
  Id id = Isar.autoIncrement;

  @Index()
  late String docId;

  late String docTitle;
  late String chunkText;

  @Index(type: IndexType.value)
  late String docType;

  late List<double> embedding;
  late DateTime addedAt;
  late int chunkIndex;
}

class VectorStore {
  static VectorStore? _instance;
  late Isar _isar;
  bool _initialized = false;

  VectorStore._();
  static VectorStore get instance => _instance ??= VectorStore._();

  Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [DocumentChunkSchema],
      directory: dir.path,
      name: 'lumina_rag_v2',
    );
    _initialized = true;
  }

  // ── Generate embedding — Gemini online or hash-based offline ──────────────
  Future<List<double>> embed(String text, {bool isQuery = false}) async {
    final geminiEmb = isQuery
        ? await GeminiRagService.instance.embedQuery(text)
        : await GeminiRagService.instance.embed(text);

    if (geminiEmb != null) return geminiEmb;

      // Offline fallback: store zero-vectors (so Isar schema is satisfied)
      // We will use keyword searching via text overlap when offline anyway!
      return List.filled(768, 0.0);
  }

  // ── Store all chunks from a document ─────────────────────────────────────
  Future<void> addChunks(
    String docId,
    String docTitle,
    List<String> chunks,
    String docType,
  ) async {
    await init();
    await deleteDoc(docId);
    await addChunksBatch(docId, docTitle, chunks, docType, startIndex: 0);
  }

  // ── Store a batch of chunks (used for progress reporting) ─────────────────
  Future<void> addChunksBatch(
    String docId,
    String docTitle,
    List<String> chunks,
    String docType, {
    required int startIndex,
  }) async {
    await init();
    final items = <DocumentChunk>[];
    for (int i = 0; i < chunks.length; i++) {
      final emb = await embed(chunks[i]);
      items.add(DocumentChunk()
        ..docId = docId
        ..docTitle = docTitle
        ..chunkText = chunks[i]
        ..docType = docType
        ..embedding = emb
        ..addedAt = DateTime.now()
        ..chunkIndex = startIndex + i);
    }
    await _isar.writeTxn(() => _isar.documentChunks.putAll(items));
  }

  // ── Semantic search — cosine similarity if online, keyword matching if offline
  Future<List<DocumentChunk>> search(String query, {int topK = 5}) async {
    await init();
    final geminiEmb = await GeminiRagService.instance.embedQuery(query);
    final all = await _isar.documentChunks.where().findAll();

    if (geminiEmb != null) {
      // Online semantic search
      final scored = all
          .map((c) => (chunk: c, score: _cosine(geminiEmb, c.embedding)))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      return scored.take(topK).map((s) => s.chunk).toList();
    } else {
      // Offline fallback: Keyword overlap (TF-IDF/Jaccard approximation)
      final qTerms = query.toLowerCase().split(RegExp(r'\W+')).where((t) => t.length > 2).toSet();
      if (qTerms.isEmpty) return all.take(topK).toList();

      final scored = all.map((c) {
        final cTerms = c.chunkText.toLowerCase().split(RegExp(r'\W+')).where((t) => t.length > 2).toSet();
        final intersect = qTerms.intersection(cTerms).length;
        // Simple overlap score favoring dense matches in shorter chunks
        final score = intersect / sqrt(cTerms.length.clamp(1, 1000)); 
        return (chunk: c, score: score);
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      // Filter to chunks that actually matched at least one keyword, unless absolutely none did
      final filtered = scored.where((s) => s.score > 0).toList();
      return (filtered.isNotEmpty ? filtered : scored).take(topK).map((s) => s.chunk).toList();
    }
  }

  // ── All indexed documents (deduplicated by docId) ─────────────────────────
  Future<List<({String docId, String docTitle, String docType, int chunks, DateTime addedAt})>> listDocs() async {
    await init();
    final all = await _isar.documentChunks.where().findAll();
    final seen = <String, ({String docId, String docTitle, String docType, int chunks, DateTime addedAt})>{};
    for (final c in all) {
      seen.update(
        c.docId,
        (v) => (docId: v.docId, docTitle: v.docTitle, docType: v.docType, chunks: v.chunks + 1, addedAt: v.addedAt),
        ifAbsent: () => (docId: c.docId, docTitle: c.docTitle, docType: c.docType, chunks: 1, addedAt: c.addedAt),
      );
    }
    return seen.values.toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  Future<void> deleteDoc(String docId) async {
    await _isar.writeTxn(
      () => _isar.documentChunks.filter().docIdEqualTo(docId).deleteAll(),
    );
  }

  Future<int> get totalChunks async {
    await init();
    return _isar.documentChunks.count();
  }

  // ── Cosine similarity ─────────────────────────────────────────────────────
  double _cosine(List<double> a, List<double> b) {
    final len = min(a.length, b.length);
    double dot = 0, na = 0, nb = 0;
    for (int i = 0; i < len; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (sqrt(na) * sqrt(nb));
  }
}
