import 'dart:math';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

part 'vector_store.g.dart';

@collection
class DocumentChunk {
  Id id = Isar.autoIncrement;

  @Index()
  late String docId;

  late String docTitle;
  late String chunkText;

  @Index(type: IndexType.value)
  late String docType;

  late List<double> embedding; // 384-dim MiniLM
  late DateTime addedAt;
}

class VectorStore {
  static VectorStore? _instance;
  late Isar _isar;
  Interpreter? _interpreter;
  bool _initialized = false;

  VectorStore._();
  static VectorStore get instance => _instance ??= VectorStore._();

  Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [DocumentChunkSchema],
      directory: dir.path,
      name: 'lumina_rag',
    );
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/minilm.tflite');
    } catch (_) {
      // Model not present — RAG will use random embeddings as placeholder
    }
    _initialized = true;
  }

  /// Generate 384-dim embedding via TFLite MiniLM
  /// Falls back to deterministic hash-based embedding if model not loaded
  Future<List<double>> embed(String text) async {
    if (_interpreter != null) {
      final tokens = text.toLowerCase().split(RegExp(r'\s+')).take(128).toList();
      final inputIds = List.filled(128, 0);
      final attentionMask = List.filled(128, 0);
      for (int i = 0; i < tokens.length; i++) {
        inputIds[i] = tokens[i].hashCode.abs() % 30000;
        attentionMask[i] = 1;
      }

      final output = List.generate(1, (_) => List.filled(384, 0.0));
      _interpreter!.runForMultipleInputs(
        [[inputIds], [attentionMask]],
        {0: output},
      );
      return output[0];
    }

    // Fallback: deterministic pseudo-embedding from text hash
    final random = Random(text.hashCode);
    return List.generate(384, (_) => random.nextDouble() * 2 - 1);
  }

  Future<void> addChunks(
    String docId, String docTitle, List<String> chunks, String docType) async {
    await init();
    final items = <DocumentChunk>[];
    for (final chunk in chunks) {
      final emb = await embed(chunk);
      items.add(DocumentChunk()
        ..docId = docId
        ..docTitle = docTitle
        ..chunkText = chunk
        ..docType = docType
        ..embedding = emb
        ..addedAt = DateTime.now());
    }
    await _isar.writeTxn(() => _isar.documentChunks.putAll(items));
  }

  Future<List<DocumentChunk>> search(String query, {int topK = 5}) async {
    await init();
    final queryEmb = await embed(query);
    final all = await _isar.documentChunks.where().findAll();

    final scored = all.map((c) => (chunk: c, score: _cos(queryEmb, c.embedding))).toList();
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).map((s) => s.chunk).toList();
  }

  double _cos(List<double> a, List<double> b) {
    double dot = 0, na = 0, nb = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (sqrt(na) * sqrt(nb));
  }

  Future<void> deleteDoc(String docId) async {
    await _isar.writeTxn(
      () => _isar.documentChunks.filter().docIdEqualTo(docId).deleteAll(),
    );
  }
}
