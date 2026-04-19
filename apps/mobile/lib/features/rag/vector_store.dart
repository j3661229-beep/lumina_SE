import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

part 'vector_store.g.dart';

/// A persisted document chunk with its 384-dim embedding.
/// Embeddings are computed on-device using the hashing trick (no server needed).
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
      name: 'lumina_rag_v3', // v3: hash embeddings (breaking change from neural/zero vectors)
    );
    _initialized = true;
  }

  // ── On-device embedding — hashing trick (pure Dart, no network) ──────────
  // Produces a 384-dim L2-normalised dense vector from word tokens + bigrams.
  // Cosine similarity between these gives meaningful keyword-overlap scores,
  // which is sufficient for RAG retrieval over student notes/textbooks.
  static List<double> embedLocal(String text, {int dims = 384}) {
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .toList();

    if (words.isEmpty) return List.filled(dims, 0.0);

    final vec = List<double>.filled(dims, 0.0);

    for (int wi = 0; wi < words.length; wi++) {
      final word = words[wi];

      // Two independent hash functions for better spread (FNV-1a style)
      int h1 = 2166136261;
      int h2 = 0x811c9dc5;
      for (final c in word.codeUnits) {
        h1 = ((h1 ^ c) * 16777619) & 0x7FFFFFFF;
        h2 = ((h2 ^ c) * 1000003) & 0x7FFFFFFF;
      }
      vec[h1 % dims] += 1.0;    // unigram, full weight
      vec[h2 % dims] += 0.6;    // unigram, secondary hash

      // Bigrams — improves phrase-level matching ("data structure", "binary tree")
      if (wi + 1 < words.length) {
        final bigram = '${word}_${words[wi + 1]}';
        int hb = 2166136261;
        for (final c in bigram.codeUnits) {
          hb = ((hb ^ c) * 16777619) & 0x7FFFFFFF;
        }
        vec[hb % dims] += 0.8;
      }

      // Trigrams — captures short phrases
      if (wi + 2 < words.length) {
        final trigram = '${word}_${words[wi + 1]}_${words[wi + 2]}';
        int ht = 0x811c9dc5;
        for (final c in trigram.codeUnits) {
          ht = ((ht ^ c) * 1000003) & 0x7FFFFFFF;
        }
        vec[ht % dims] += 0.5;
      }
    }

    // L2-normalise so cosine similarity = dot product
    var norm = 0.0;
    for (final v in vec) norm += v * v;
    norm = sqrt(norm);
    if (norm > 0) {
      for (int i = 0; i < dims; i++) vec[i] /= norm;
    }
    return vec;
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

  // ── Store a batch of chunks — pure on-device, no network calls ───────────
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
      final emb = embedLocal(chunks[i]);  // pure Dart, no network
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
    debugPrint('[VectorStore] Stored batch: startIndex=$startIndex, count=${items.length}, docId=$docId');
  }

  // ── Semantic search — cosine similarity on local hash embeddings ──────────
  Future<List<DocumentChunk>> search(String query, {int topK = 5}) async {
    await init();
    final qEmb = embedLocal(query);
    final all = await _isar.documentChunks.where().findAll();

    debugPrint('[VectorStore] search() — total chunks in DB: ${all.length}');
    if (all.isEmpty) return [];

    final scored = all
        .map((c) => (chunk: c, score: _cosine(qEmb, c.embedding)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final top = scored.take(topK).toList();
    for (final s in top) {
      debugPrint('[VectorStore] score=${s.score.toStringAsFixed(4)} | ${s.chunk.chunkText.substring(0, s.chunk.chunkText.length.clamp(0, 80))}');
    }

    final results = scored.where((s) => s.score > 0.01).take(topK).toList();
    return (results.isNotEmpty ? results : scored.take(topK).toList())
        .map((s) => s.chunk)
        .toList();
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

  /// Wipe ALL indexed chunks — use after embedding schema changes
  Future<void> clearAll() async {
    await init();
    await _isar.writeTxn(() => _isar.documentChunks.clear());
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
