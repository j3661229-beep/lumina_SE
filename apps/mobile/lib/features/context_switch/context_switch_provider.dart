import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

final contextSwitchProvider =
    AsyncNotifierProvider<ContextSwitchNotifier, CognitiveState>(ContextSwitchNotifier.new);

class CognitiveState {
  final double score;
  final List<Map<String, dynamic>> history; // last 7 days
  const CognitiveState({required this.score, required this.history});
}

class ContextSwitchNotifier extends AsyncNotifier<CognitiveState> {
  Timer? _flushTimer;

  @override
  Future<CognitiveState> build() async {
    _startCollection();
    return _fetchState();
  }

  void _startCollection() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      state = await AsyncValue.guard(() => _fetchState());
    });
  }

  Future<CognitiveState> _fetchState() async {
    final data = await ApiClient.instance.get<List<dynamic>>('/context-switch/score');
    final list = List<Map<String, dynamic>>.from(data);
    final score = list.isEmpty ? 0.0 : (list.first['score'] as num).toDouble();
    return CognitiveState(score: score, history: list);
  }

  Future<void> seedDemoData() async {
    try {
      await ApiClient.instance.post('/demo/seed', data: {});
      state = await AsyncValue.guard(_fetchState);
    } catch (e) {
      print('Demo seed failed: $e');
    }
  }

  Future<void> logSession({
    required String appName,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      await ApiClient.instance.post('/context-switch/batch', data: {
        'sessions': [
          {
            'app_name': appName,
            'session_start': start.toIso8601String(),
            'session_end': end.toIso8601String(),
          }
        ],
      });
      state = await AsyncValue.guard(_fetchState);
    } catch (_) {}
  }
}
