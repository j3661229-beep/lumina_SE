import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';

/// Handles RAG pipeline using the Local Offline Node AI server over ApiClient
/// Falls back to Gemini strictly if Local processing fails.
class GeminiRagService {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY',
      defaultValue: 'ERROR_API_KEY_NOT_CONFIGURED');
  static const _embedUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent';
  static const _chatUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static GeminiRagService? _instance;
  static GeminiRagService get instance => _instance ??= GeminiRagService._();
  GeminiRagService._();

  Future<bool> isOnline() async => true; // Dummy for rag_provider compatibility

  // ── Embed Text ──────────────────────────────────────────────────────────
  Future<List<double>?> embed(String text) async {
    try {
      // 1. Try fully local, offline inference first
      final res = await ApiClient.instance.post('/rag/embed', data: {'text': text});
      final arr = res['embedding'] as List<dynamic>;
      return arr.map((e) => (e as num).toDouble()).toList();
    } catch (e) {
      // 2. Fallback to Gemini if backend AI is unavailable
      print('[LocalRAG] Embed failed, falling back to Gemini: $e');
      return _embedGemini(text, isQuery: false);
    }
  }

  Future<List<double>?> embedQuery(String query) async {
    try {
      // 1. Try fully local, offline inference
      final res = await ApiClient.instance.post('/rag/embed', data: {'text': query});
      final arr = res['embedding'] as List<dynamic>;
      return arr.map((e) => (e as num).toDouble()).toList();
    } catch (e) {
      print('[LocalRAG] Query Embed failed, falling back to Gemini: $e');
      return _embedGemini(query, isQuery: true);
    }
  }

  Future<List<double>?> _embedGemini(String text, {required bool isQuery}) async {
    try {
      final res = await _dio.post(
        '$_embedUrl?key=$_apiKey',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: {
          'model': 'models/text-embedding-004',
          'content': {'parts': [{'text': text}]},
          'taskType': isQuery ? 'RETRIEVAL_QUERY' : 'RETRIEVAL_DOCUMENT',
        },
      );
      return (res.data['embedding']['values'] as List)
          .map<double>((v) => (v as num).toDouble())
          .toList();
    } catch (_) {
      return List.filled(384, 0.0); // Return dummy offline embeddings
    }
  }

  // ── Synthesise Chat ─────────────────────────────────────────────────────
  Future<String> synthesise(String query, List<String> chunks) async {
    try {
      // 1. Try full offline generation (Xenova / TinyLlama)
      final res = await ApiClient.instance.post('/rag/chat', data: {
        'query': query,
        'chunks': chunks
      });
      final answer = res['text'] as String?;
      if (answer != null && answer.isNotEmpty) return answer;
      throw Exception("Empty response");
    } catch (e) {
      print('[LocalRAG] Chat failed, falling back to Gemini: $e');
      // 2. Fallback to Gemini
      return _synthesiseGemini(query, chunks);
    }
  }

  Future<String> _synthesiseGemini(String query, List<String> chunks) async {
    final context = chunks.asMap().entries.map((e) => '[${e.key + 1}] ${e.value}').join('\n\n');
    try {
      final res = await _dio.post(
        '$_chatUrl?key=$_apiKey',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: {
          'contents': [{
            'role': 'user',
            'parts': [{
              'text': '''You are a proactive engineering sidekick. Answer the question using ONLY the provided excerpts.
QUESTION: $query
EXCERPTS:
$context
ANSWER:'''
            }]
          }],
          'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 512},
        },
      );
      return res.data['candidates'][0]['content']['parts'][0]['text'] as String;
    } catch (e) {
      final fallbackContext = chunks.map((c) => '> ${c.replaceAll('\n', '\n> ')}').join('\n\n');
      return '*(Offline Mode)* Here are the most relevant excerpts from your notes:\n\n$fallbackContext';
    }
  }
}
