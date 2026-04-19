import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

// ── Platform Channel ─────────────────────────────────────────────────────────
const _channel = MethodChannel('com.lumina/context_switch');

// ── Data Models ──────────────────────────────────────────────────────────────

/// A single foreground app session (from UsageStatsManager or simulated).
class AppSession {
  final String packageName;
  final String appName;
  final DateTime startTime;
  final DateTime endTime;

  Duration get duration => endTime.difference(startTime);
  bool get isShortSwitch => duration.inSeconds < 120;

  const AppSession({
    required this.packageName,
    required this.appName,
    required this.startTime,
    required this.endTime,
  });

  factory AppSession.fromMap(Map<dynamic, dynamic> m) => AppSession(
        packageName: m['packageName'] as String,
        appName: m['appName'] as String,
        startTime: DateTime.fromMillisecondsSinceEpoch(m['startTime'] as int),
        endTime: DateTime.fromMillisecondsSinceEpoch(m['endTime'] as int),
      );

  Map<String, String> toApiMap() => {
        'app_name': appName,
        'package_name': packageName,
        'session_start': startTime.toIso8601String(),
        'session_end': endTime.toIso8601String(),
      };
}

/// Full state exposed to the UI.
class CognitiveState {
  final double score;          // 0–100 cognitive debt
  final bool hasPermission;
  final bool isMonitoring;
  final List<AppSession> timeline;      // today's app sessions
  final List<Map<String, dynamic>> scoreHistory; // last 7 days from server
  final List<Map<String, dynamic>> squadSnapshots; // anonymized squad data
  final String? statusMessage;

  const CognitiveState({
    this.score = 0,
    this.hasPermission = false,
    this.isMonitoring = false,
    this.timeline = const [],
    this.scoreHistory = const [],
    this.squadSnapshots = const [],
    this.statusMessage,
  });

  CognitiveState copyWith({
    double? score,
    bool? hasPermission,
    bool? isMonitoring,
    List<AppSession>? timeline,
    List<Map<String, dynamic>>? scoreHistory,
    List<Map<String, dynamic>>? squadSnapshots,
    String? statusMessage,
  }) => CognitiveState(
    score: score ?? this.score,
    hasPermission: hasPermission ?? this.hasPermission,
    isMonitoring: isMonitoring ?? this.isMonitoring,
    timeline: timeline ?? this.timeline,
    scoreHistory: scoreHistory ?? this.scoreHistory,
    squadSnapshots: squadSnapshots ?? this.squadSnapshots,
    statusMessage: statusMessage ?? this.statusMessage,
  );
}

// ── Providers ────────────────────────────────────────────────────────────────
final contextSwitchProvider =
    AsyncNotifierProvider<ContextSwitchNotifier, CognitiveState>(
        ContextSwitchNotifier.new);

// ── Notifier ─────────────────────────────────────────────────────────────────
class ContextSwitchNotifier extends AsyncNotifier<CognitiveState> {
  Timer? _pollTimer;
  Timer? _syncTimer;
  Timer? _demoTimer;

  @override
  Future<CognitiveState> build() async {
    ref.onDispose(() {
      _pollTimer?.cancel();
      _syncTimer?.cancel();
      _demoTimer?.cancel();
    });

    final hasPerm = await _checkPermission();
    var state = CognitiveState(hasPermission: hasPerm);

    // Fetch 7-day history from backend (best-effort)
    try {
      final data = await ApiClient.instance.get<List<dynamic>>('/context-switch/score');
      final list = List<Map<String, dynamic>>.from(data);
      final serverScore = list.isEmpty ? 0.0 : (list.first['score'] as num).toDouble();
      state = state.copyWith(scoreHistory: list, score: serverScore);
    } catch (_) {}

    if (hasPerm) {
      _startMonitoring();
    }

    return state;
  }

  // ── Permission ──────────────────────────────────────────────────────────────
  Future<bool> _checkPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasUsagePermission') ?? false;
    } catch (_) { return false; }
  }

  Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestUsagePermission');
      // Poll for permission grant (user may take a few seconds in Settings)
      _demoTimer?.cancel();
      _demoTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        final granted = await _checkPermission();
        if (granted) {
          _demoTimer?.cancel();
          state = AsyncData((state.value ?? const CognitiveState()).copyWith(hasPermission: true));
          _startMonitoring();
        }
      });
    } catch (_) {}
  }

  // ── Monitoring Engine ───────────────────────────────────────────────────────
  void _startMonitoring() {
    _pollTimer?.cancel();
    // Poll every 15s for new foreground events
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
    // Sync to backend every 5 min
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => _syncToBackend());
    // Immediate first poll
    _poll();
  }

  Future<void> _poll() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getRecentEvents', {'minutes': 60});
      if (raw == null) return;
      final sessions = raw
          .cast<Map<dynamic, dynamic>>()
          .map(AppSession.fromMap)
          .where((s) => s.duration.inSeconds > 5)
          .toList();

      final debt = _computeDebt(sessions);
      final current = state.value ?? const CognitiveState();
      state = AsyncData(current.copyWith(
        timeline: sessions,
        score: debt,
        isMonitoring: true,
        statusMessage: _debtMessage(debt, sessions.length),
      ));
    } catch (e) {
      debugPrint('[ContextSwitch] Poll error: $e');
    }
  }

  Future<void> _syncToBackend() async {
    final sessions = state.value?.timeline ?? [];
    if (sessions.isEmpty) return;
    try {
      await ApiClient.instance.post('/context-switch/batch', data: {
        'sessions': sessions.map((s) => s.toApiMap()).toList(),
      });
    } catch (_) {}
  }

  // ── Cognitive Debt — Exponential Decay ─────────────────────────────────────
  // debt(t) = Σ weight_i * exp(-λ * minutes_since_switch_i)
  // λ = 0.05 → half-life ≈ 14 min
  // Short sessions (<2 min) get 3× penalty (rapid task switching)
  static double _computeDebt(List<AppSession> sessions) {
    const lambda = 0.05;
    final now = DateTime.now();
    double debt = 0;

    for (final s in sessions) {
      final minSince = now.difference(s.endTime).inSeconds / 60.0;
      final weight = s.isShortSwitch ? 3.0 : 1.0;
      debt += weight * exp(-lambda * minSince);
    }
    return min(100, (debt * 100).roundToDouble() / 100);
  }

  String _debtMessage(double debt, int switches) {
    if (switches == 0) return 'No activity detected yet.';
    if (debt < 20) return '🧠 Deep focus — $switches apps in 1h';
    if (debt < 50) return '⚡ Moderate switching — watch out!';
    if (debt < 75) return '⚠️ High cognitive load — $switches switches!';
    return '🔴 Critical! ${switches} rapid switches detected.';
  }

  // ── Study Squads ──────────────────────────────────────────────────────────
  Future<void> shareToSquad(String groupId) async {
    final sessions = state.value?.timeline ?? [];
    if (sessions.isEmpty) return;

    // Build anonymized debt curve (score sampled every 5 min)
    final curve = _buildDebtCurve(sessions);

    try {
      await ApiClient.instance.post('/context-switch/squad-snapshot', data: {
        'group_id': groupId,
        'debt_curve': curve,
      });
      final current = state.value ?? const CognitiveState();
      state = AsyncData(current.copyWith(statusMessage: '✅ Flow graph shared to squad!'));
    } catch (e) {
      debugPrint('[ContextSwitch] Squad share error: $e');
    }
  }

  List<Map<String, dynamic>> _buildDebtCurve(List<AppSession> sessions) {
    if (sessions.isEmpty) return [];
    final curve = <Map<String, dynamic>>[];
    final first = sessions.first.startTime;
    const step = Duration(minutes: 5);

    for (int i = 0; i < 12; i++) { // 12 × 5min = 1h
      final windowEnd = first.add(step * (i + 1));
      final inWindow = sessions.where((s) => s.startTime.isBefore(windowEnd)).toList();
      curve.add({'t': i * 5, 'score': _computeDebt(inWindow)});
    }
    return curve;
  }

  // ── Seed demo data ────────────────────────────────────────────────────────
  Future<void> seedDemoData() async {
    try {
      await ApiClient.instance.post('/demo/seed', data: {});
      // Also inject synthetic local timeline for immediate UI feedback
      final now = DateTime.now();
      final synthetic = [
        AppSession(appName: 'Instagram', packageName: 'com.instagram.android',
            startTime: now.subtract(const Duration(minutes: 40)),
            endTime: now.subtract(const Duration(minutes: 39))),
        AppSession(appName: 'YouTube', packageName: 'com.google.android.youtube',
            startTime: now.subtract(const Duration(minutes: 38)),
            endTime: now.subtract(const Duration(minutes: 32))),
        AppSession(appName: 'WhatsApp', packageName: 'com.whatsapp',
            startTime: now.subtract(const Duration(minutes: 32)),
            endTime: now.subtract(const Duration(minutes: 31))),
        AppSession(appName: 'Lumina', packageName: 'com.lumina.lumina',
            startTime: now.subtract(const Duration(minutes: 30)),
            endTime: now.subtract(const Duration(minutes: 5))),
        AppSession(appName: 'Instagram', packageName: 'com.instagram.android',
            startTime: now.subtract(const Duration(minutes: 5)),
            endTime: now.subtract(const Duration(minutes: 4))),
      ];
      final debt = _computeDebt(synthetic);
      state = AsyncData((state.value ?? const CognitiveState()).copyWith(
        timeline: synthetic,
        score: debt,
        statusMessage: '✨ Demo data loaded',
      ));
    } catch (e) {
      debugPrint('[ContextSwitch] Demo seed: $e');
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }

  // ── Legacy API compat ─────────────────────────────────────────────────────
  Future<void> logSession({
    required String appName,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      await ApiClient.instance.post('/context-switch/batch', data: {
        'sessions': [{'app_name': appName, 'session_start': start.toIso8601String(), 'session_end': end.toIso8601String()}],
      });
    } catch (_) {}
  }
}
