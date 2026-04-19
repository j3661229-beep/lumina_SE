/// Fully on-device RAG synthesis service.
/// Zero network calls. Zero cloud. Works with no internet and no backend.
///
/// Pipeline:
///   1. Embeddings  → VectorStore.embedLocal() [pure Dart, instant]
///   2. Vector search → Isar + cosine similarity [local]
///   3. Synthesis   → Extractive sentence scoring [pure Dart, instant]
class GeminiRagService {
  static GeminiRagService? _instance;
  static GeminiRagService get instance => _instance ??= GeminiRagService._();
  GeminiRagService._();

  // Kept for API compatibility — everything is local now
  Future<bool> isOnline() async => false;

  // These methods are unused now (VectorStore.embedLocal() is called directly),
  // but kept for compatibility.
  Future<List<double>?> embed(String text) async => null;
  Future<List<double>?> embedQuery(String query) async => null;

  // ── Synthesise answer — fully offline ─────────────────────────────────────
  Future<String> synthesise(String query, List<String> chunks) async {
    if (chunks.isEmpty) {
      return 'No relevant content found. Try uploading your notes first.';
    }
    return _extractiveAnswer(query, chunks);
  }

  // ── Extractive QA ─────────────────────────────────────────────────────────
  String _extractiveAnswer(String query, List<String> chunks) {
    final stopwords = {
      'the', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
      'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would',
      'shall', 'should', 'may', 'might', 'must', 'can', 'could',
      'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'with', 'by', 'from', 'as', 'into', 'about', 'what',
      'how', 'why', 'when', 'where', 'who', 'which', 'that', 'this',
      'it', 'its', 'me', 'my', 'we', 'our', 'you', 'your', 'i',
      'explain', 'describe', 'tell', 'give', 'please', 'define',
    };

    final qTokens = query
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((t) => t.length > 2 && !stopwords.contains(t))
        .toSet();

    if (qTokens.isEmpty) {
      return _cleanExcerpt(chunks.first);
    }

    // ── Step 1: Score every candidate passage ──────────────────────────────
    // We use two levels: full chunk scoring AND sentence-level scoring.
    // Try sentences first; if none match well, score full chunks.

    final sentenceScores = <({String text, double score})>[];

    for (int ci = 0; ci < chunks.length && ci < 5; ci++) {
      final chunk = chunks[ci];

      // Split into sentences — handles period, exclamation, question mark boundaries
      // Also splits on bullet-point patterns common in textbooks (• prefix)
      final raw = chunk.split(RegExp(r'(?<=[.!?])\s+|(?=\s*[•\-]\s)'));
      final sentences = raw
          .map((s) => s.replaceAll(RegExp(r'^[•\-\s]+'), '').trim())
          .where((s) => s.length > 20)
          .toList();

      for (final sentence in sentences) {
        final sTokens = sentence
            .toLowerCase()
            .split(RegExp(r'\W+'))
            .where((t) => t.length > 2)
            .toSet();

        final overlap = qTokens.intersection(sTokens).length;
        if (overlap == 0) continue;

        // Score: overlap density + position bonus
        final density = overlap / (sTokens.length.clamp(1, 500) * 0.25 + 1);
        final posBonus = 1.0 / (ci * 0.4 + 1);
        sentenceScores.add((text: sentence, score: density * posBonus * overlap));
      }
    }

    // ── Step 2: If we have sentence-level matches, use them ────────────────
    if (sentenceScores.isNotEmpty) {
      sentenceScores.sort((a, b) => b.score.compareTo(a.score));

      final selected = <String>[];
      for (final s in sentenceScores) {
        if (selected.length >= 3) break;
        // Dedup: skip if >55% word overlap with already selected
        final sWords = s.text.toLowerCase().split(RegExp(r'\W+')).toSet();
        final isDup = selected.any((prev) {
          final pWords = prev.toLowerCase().split(RegExp(r'\W+')).toSet();
          final inter = sWords.intersection(pWords).length;
          return inter / sWords.length.clamp(1, 9999) > 0.55;
        });
        if (!isDup) selected.add(s.text);
      }

      if (selected.isNotEmpty) {
        final answer = selected.join(' ');
        return '$answer\n\n─ *Extracted from your notes*';
      }
    }

    // ── Step 3: Fallback — score full chunks, return top chunk excerpt ─────
    // This handles the case where the chunk has no clear sentence boundaries.
    final chunkScores = chunks.take(5).toList().asMap().entries.map((e) {
      final cTokens = e.value
          .toLowerCase()
          .split(RegExp(r'\W+'))
          .where((t) => t.length > 2)
          .toSet();
      final overlap = qTokens.intersection(cTokens).length;
      return (chunk: e.value, score: overlap.toDouble(), idx: e.key);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final bestChunk = chunkScores.first.chunk;
    return _cleanExcerpt(bestChunk);
  }

  /// Returns clean excerpt from a chunk, snapped to sentence boundary
  String _cleanExcerpt(String chunk) {
    final trimmed = chunk.trim();
    if (trimmed.length <= 400) return '$trimmed\n\n─ *From your notes*';
    final sub = trimmed.substring(0, 400);
    // Try to snap back to the last complete sentence
    final lastDot = sub.lastIndexOf('. ');
    final excerpt = lastDot > 80 ? sub.substring(0, lastDot + 1) : sub;
    return '$excerpt…\n\n─ *From your notes*';
  }
}
