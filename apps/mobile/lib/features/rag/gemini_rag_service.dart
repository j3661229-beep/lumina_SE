import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Handles all Gemini API calls for the RAG pipeline:
/// - text-embedding-004 for generating 768-dim vectors
/// - gemini-1.5-flash for synthesising answers from retrieved chunks
class GeminiRagService {
  static const _apiKey = 'AIzaSyA28U_YTWIZxXWxSCj2gxESlKG_3nGMo-A';
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

  // ── Check connectivity ────────────────────────────────────────────────────
  Future<bool> isOnline() async {
    // Forcing completely offline operations for now, as requested.
    // To restore API usage, uncomment below:
    // final result = await Connectivity().checkConnectivity();
    // return result.isNotEmpty && result.first != ConnectivityResult.none;
    return false;
  }

  // ── Generate 768-dim embedding for a text chunk ───────────────────────────
  Future<List<double>?> embed(String text) async {
    if (!await isOnline()) return null;
    try {
      final res = await _dio.post(
        '$_embedUrl?key=$_apiKey',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: jsonEncode({
          'model': 'models/text-embedding-004',
          'content': {'parts': [{'text': text}]},
          'taskType': 'RETRIEVAL_DOCUMENT',
        }),
      );
      final values = (res.data['embedding']['values'] as List)
          .map<double>((v) => (v as num).toDouble())
          .toList();
      return values;
    } catch (e) {
      return null;
    }
  }

  // ── Generate embedding for a user query ───────────────────────────────────
  Future<List<double>?> embedQuery(String query) async {
    if (!await isOnline()) return null;
    try {
      final res = await _dio.post(
        '$_embedUrl?key=$_apiKey',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: jsonEncode({
          'model': 'models/text-embedding-004',
          'content': {'parts': [{'text': query}]},
          'taskType': 'RETRIEVAL_QUERY',
        }),
      );
      final values = (res.data['embedding']['values'] as List)
          .map<double>((v) => (v as num).toDouble())
          .toList();
      return values;
    } catch (e) {
      return null;
    }
  }

  // ── Synthesise an answer from retrieved context chunks ────────────────────
  Future<String> synthesise(String query, List<String> chunks) async {
    if (!await isOnline()) {
      final context = chunks.asMap().entries.map((e) => '> ${e.value.replaceAll('\n', '\n> ')}').join('\n\n');
      return '*(Offline Mode)* Here are the most relevant excerpts from your documents:\n\n$context';
    }
    final context = chunks.asMap().entries.map((e) => '[${e.key + 1}] ${e.value}').join('\n\n');
    try {
      final res = await _dio.post(
        '$_chatUrl?key=$_apiKey',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: jsonEncode({
          'contents': [{
            'role': 'user',
            'parts': [{
              'text': '''You are a helpful study assistant. Answer the student's question based ONLY on the provided textbook/note excerpts. Be concise and clear. If the answer is not in the excerpts, say so.

STUDENT QUESTION: $query

RETRIEVED EXCERPTS:
$context

ANSWER:'''
            }]
          }],
          'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 512},
        }),
      );
      return res.data['candidates'][0]['content']['parts'][0]['text'] as String;
    } catch (e) {
      // If the API crashes (e.g. 404, rate limit), fallback gracefully to local chunks
      // instead of showing ugly DioExceptions to the user.
      final fallbackContext = chunks.asMap().entries.map((e) => '> ${e.value.replaceAll('\n', '\n> ')}').join('\n\n');
      return '*(Offline / Fallback)* We could not reach Lumina AI at the moment. Here are the most relevant excerpts from your notes:\n\n$fallbackContext';
    }
  }
}
