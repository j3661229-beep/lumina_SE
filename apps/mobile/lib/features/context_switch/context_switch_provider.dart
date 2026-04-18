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
    try {
      final data = await ApiClient.instance.get<List<dynamic>>('/context-switch/score');
      final list = List<Map<String, dynamic>>.from(data);
      final score = list.isEmpty ? 0.0 : (list.first['score'] as num).toDouble();
      return CognitiveState(score: score, history: list);
    } catch (_) {
      // Return demo data if backend not reachable yet
      return CognitiveState(score: 32.0, history: _demoHistory());
    }
  }

  static List<Map<String, dynamic>> _demoHistory() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return {
        'score': [12.0, 45.0, 28.0, 67.0, 33.0, 55.0, 32.0][i],
        'windowDate': day.toIso8601String(),
      };
    });
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
