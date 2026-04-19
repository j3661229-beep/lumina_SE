import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/notifications/notification_service.dart';

// ── Platform Channel ─────────────────────────────────────────────────────────
const _channel = MethodChannel('com.lumina/context_switch');

// ── Prefs keys ───────────────────────────────────────────────────────────────
const _kDndEnabled  = 'cs_dnd_enabled';
const _kBlockedApps = 'cs_blocked_apps'; // JSON list of packageName strings
// Note: Flutter SharedPreferences stores keys on Android with flutter. prefix
// in the native FlutterSharedPreferences file. LuminaBlockService reads:
//   flutter.cs_dnd_enabled  and  flutter.cs_blocked_apps

// ── Data Models ──────────────────────────────────────────────────────────────

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

/// An installed app on the device (for DND picker).
class InstalledApp {
  final String packageName;
  final String appName;
  const InstalledApp({required this.packageName, required this.appName});
  factory InstalledApp.fromMap(Map<dynamic, dynamic> m) =>
      InstalledApp(packageName: m['packageName'] as String, appName: m['appName'] as String);
}

class CognitiveState {
  final double score;
  final bool hasPermission;
  final bool isMonitoring;
  final List<AppSession> timeline;
  final List<Map<String, dynamic>> scoreHistory;
  final String? statusMessage;
  // ── DND ──
  final bool dndEnabled;
  final List<String> blockedPackages;   // packages user has selected to block
  final List<InstalledApp> installedApps; // for the picker; loaded lazily
  final String? currentFgApp;           // real-time foreground package
  final String? dndAlert;               // message when a blocked app is detected
  final bool hasAccessibilityPermission; // true → LuminaBlockService is enabled

  const CognitiveState({
    this.score = 0,
    this.hasPermission = false,
    this.isMonitoring = false,
    this.timeline = const [],
    this.scoreHistory = const [],
    this.statusMessage,
    this.dndEnabled = false,
    this.blockedPackages = const [],
    this.installedApps = const [],
    this.currentFgApp,
    this.dndAlert,
    this.hasAccessibilityPermission = false,
  });

  CognitiveState copyWith({
    double? score,
    bool? hasPermission,
    bool? isMonitoring,
    List<AppSession>? timeline,
    List<Map<String, dynamic>>? scoreHistory,
    String? statusMessage,
    bool? dndEnabled,
    List<String>? blockedPackages,
    List<InstalledApp>? installedApps,
    String? currentFgApp,
    String? dndAlert,
    bool? hasAccessibilityPermission,
  }) => CognitiveState(
    score: score ?? this.score,
    hasPermission: hasPermission ?? this.hasPermission,
    isMonitoring: isMonitoring ?? this.isMonitoring,
    timeline: timeline ?? this.timeline,
    scoreHistory: scoreHistory ?? this.scoreHistory,
    statusMessage: statusMessage ?? this.statusMessage,
    dndEnabled: dndEnabled ?? this.dndEnabled,
    blockedPackages: blockedPackages ?? this.blockedPackages,
    installedApps: installedApps ?? this.installedApps,
    currentFgApp: currentFgApp ?? this.currentFgApp,
    dndAlert: dndAlert,
    hasAccessibilityPermission: hasAccessibilityPermission ?? this.hasAccessibilityPermission,
  );
}

// ── Providers ────────────────────────────────────────────────────────────────
final contextSwitchProvider =
    AsyncNotifierProvider<ContextSwitchNotifier, CognitiveState>(
        ContextSwitchNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
class ContextSwitchNotifier extends AsyncNotifier<CognitiveState> {
  Timer? _pollTimer;          // usage events poll (15s normal / 4s DND)
  Timer? _fgPollTimer;        // foreground-app poll (5s in DND mode)
  Timer? _syncTimer;
  Timer? _permGrantPollTimer;

  // Tracks which blocked apps we've already alerted for in this DND session
  // (resets on DND toggle) so we don't spam notifications.
  final Set<String> _alertedThisSession = {};

  @override
  Future<CognitiveState> build() async {
    ref.onDispose(() {
      _pollTimer?.cancel();
      _fgPollTimer?.cancel();
      _syncTimer?.cancel();
      _permGrantPollTimer?.cancel();
    });

    final prefs = await SharedPreferences.getInstance();
    final hasPerm = await _checkPermission();
    final hasA11y = await _checkAccessibilityPermission();
    final dndEnabled = prefs.getBool(_kDndEnabled) ?? false;
    final blocked = (jsonDecode(prefs.getString(_kBlockedApps) ?? '[]') as List)
        .cast<String>();

    var s = CognitiveState(
      hasPermission: hasPerm,
      hasAccessibilityPermission: hasA11y,
      dndEnabled: dndEnabled,
      blockedPackages: blocked,
    );

    // Fetch 7-day history (best effort)
    try {
      final data = await ApiClient.instance.get<List<dynamic>>('/context-switch/score');
      final list = List<Map<String, dynamic>>.from(data);
      final serverScore = list.isEmpty ? 0.0 : (list.first['score'] as num).toDouble();
      s = s.copyWith(scoreHistory: list, score: serverScore);
    } catch (_) {}

    if (hasPerm) {
      _startMonitoring(dndEnabled: dndEnabled);
    }

    return s;
  }

  // ── Permission ──────────────────────────────────────────────────────────────
  Future<bool> _checkPermission() async {
    try { return await _channel.invokeMethod<bool>('hasUsagePermission') ?? false; }
    catch (_) { return false; }
  }

  Future<bool> _checkAccessibilityPermission() async {
    try { return await _channel.invokeMethod<bool>('hasAccessibilityPermission') ?? false; }
    catch (_) { return false; }
  }

  Future<void> requestAccessibilityPermission() async {
    try { await _channel.invokeMethod('requestAccessibilityPermission'); } catch (_) {}
    // Poll until enabled
    _permGrantPollTimer?.cancel();
    _permGrantPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final granted = await _checkAccessibilityPermission();
      if (granted) {
        _permGrantPollTimer?.cancel();
        final cur = state.value ?? const CognitiveState();
        state = AsyncData(cur.copyWith(
          hasAccessibilityPermission: true,
          statusMessage: '🛡️ Focus Block active — apps will be blocked instantly',
        ));
      }
    });
  }

  Future<void> requestPermission() async {
    try { await _channel.invokeMethod('requestUsagePermission'); } catch (_) {}
    _permGrantPollTimer?.cancel();
    _permGrantPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final granted = await _checkPermission();
      if (granted) {
        _permGrantPollTimer?.cancel();
        final cur = state.value ?? const CognitiveState();
        state = AsyncData(cur.copyWith(hasPermission: true));
        _startMonitoring(dndEnabled: cur.dndEnabled);
      }
    });
  }

  // ── Monitoring ──────────────────────────────────────────────────────────────
  void _startMonitoring({required bool dndEnabled}) {
    // Usage-events poll: 15s normal, 10s DND
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
        Duration(seconds: dndEnabled ? 10 : 15), (_) => _pollUsageEvents());

    // Foreground-app poll: only in DND mode (4s)
    _fgPollTimer?.cancel();
    if (dndEnabled) {
      _fgPollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollForegroundApp());
    }

    // Backend sync every 5 min
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => _syncToBackend());

    _pollUsageEvents(); // first immediate poll
    if (dndEnabled) _pollForegroundApp();
  }

  /// Poll hourly usage events for the timeline + debt score.
  Future<void> _pollUsageEvents() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getRecentEvents', {'minutes': 60});
      if (raw == null) return;
      final sessions = raw
          .cast<Map<dynamic, dynamic>>()
          .map(AppSession.fromMap)
          .where((s) => s.duration.inSeconds > 5)
          .toList();
      final debt = _computeDebt(sessions);
      final cur = state.value ?? const CognitiveState();
      state = AsyncData(cur.copyWith(
        timeline: sessions,
        score: debt,
        isMonitoring: true,
        statusMessage: _debtMessage(debt, sessions.length),
      ));
    } catch (e) {
      debugPrint('[ContextSwitch] Poll error: $e');
    }
  }

  /// Poll the current foreground app every 4s in DND mode.
  Future<void> _pollForegroundApp() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('getForegroundApp');
      if (raw == null) return;
      final pkg = raw['packageName'] as String?;
      final appName = raw['appName'] as String? ?? pkg ?? 'Unknown';
      final cur = state.value ?? const CognitiveState();
      if (!cur.dndEnabled || pkg == null) return;

      state = AsyncData(cur.copyWith(currentFgApp: pkg));

      // ── DND enforcement ──────────────────────────────────────────────────
      if (cur.blockedPackages.contains(pkg) && !_alertedThisSession.contains(pkg)) {
        _alertedThisSession.add(pkg);
        state = AsyncData((state.value ?? const CognitiveState()).copyWith(
          dndAlert: '$appName is in your Focus Block list!',
        ));
        // Fire system notification
        await NotificationService.instance.show(
          title: '📵 Focus Mode Active',
          body: 'You opened $appName — it\'s on your block list. Stay focused! 🧠',
          channelId: 'lumina_dnd',
        );
      }
    } catch (e) {
      debugPrint('[ContextSwitch] FG poll error: $e');
    }
  }

  // ── DND Mode ──────────────────────────────────────────────────────────────
  Future<void> toggleDnd({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDndEnabled, enabled);
    _alertedThisSession.clear();

    final cur = state.value ?? const CognitiveState();
    state = AsyncData(cur.copyWith(
      dndEnabled: enabled,
      dndAlert: null,
      statusMessage: enabled
          ? '📵 Focus Mode ON — monitoring ${cur.blockedPackages.length} blocked apps'
          : '✅ Focus Mode OFF',
    ));

    _startMonitoring(dndEnabled: enabled);
    if (!enabled) _fgPollTimer?.cancel();
  }

  Future<void> setBlockedApps(List<String> packages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBlockedApps, jsonEncode(packages));
    _alertedThisSession.clear();
    final cur = state.value ?? const CognitiveState();
    state = AsyncData(cur.copyWith(
      blockedPackages: packages,
      statusMessage: '${packages.length} app${packages.length == 1 ? "" : "s"} in block list',
    ));
  }

  /// Load all installed apps from the device for the picker. Cached in state.
  Future<void> loadInstalledApps() async {
    if ((state.value?.installedApps ?? []).isNotEmpty) return;
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
      if (raw == null) return;
      final apps = raw.cast<Map<dynamic, dynamic>>().map(InstalledApp.fromMap).toList();
      final cur = state.value ?? const CognitiveState();
      state = AsyncData(cur.copyWith(installedApps: apps));
    } catch (e) {
      debugPrint('[ContextSwitch] getInstalledApps error: $e');
    }
  }

  void clearDndAlert() {
    final cur = state.value ?? const CognitiveState();
    state = AsyncData(cur.copyWith(dndAlert: null));
  }

  // ── Cognitive Debt Formula ─────────────────────────────────────────────────
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
    return '🔴 Critical! $switches rapid switches detected.';
  }

  // ── Backend sync ─────────────────────────────────────────────────────────
  Future<void> _syncToBackend() async {
    final sessions = state.value?.timeline ?? [];
    if (sessions.isEmpty) return;
    try {
      await ApiClient.instance.post('/context-switch/batch', data: {
        'sessions': sessions.map((s) => s.toApiMap()).toList(),
      });
    } catch (_) {}
  }

  // ── Study Squads ─────────────────────────────────────────────────────────
  Future<void> shareToSquad(String groupId) async {
    final sessions = state.value?.timeline ?? [];
    final curve = _buildDebtCurve(sessions);
    try {
      await ApiClient.instance.post('/context-switch/squad-snapshot', data: {
        'group_id': groupId,
        'debt_curve': curve,
      });
      final cur = state.value ?? const CognitiveState();
      state = AsyncData(cur.copyWith(statusMessage: '✅ Flow graph shared to squad!'));
    } catch (e) {
      debugPrint('[ContextSwitch] Squad share error: $e');
    }
  }

  List<Map<String, dynamic>> _buildDebtCurve(List<AppSession> sessions) {
    if (sessions.isEmpty) return [];
    final curve = <Map<String, dynamic>>[];
    final first = sessions.first.startTime;
    const step = Duration(minutes: 5);
    for (int i = 0; i < 12; i++) {
      final windowEnd = first.add(step * (i + 1));
      final inWindow = sessions.where((s) => s.startTime.isBefore(windowEnd)).toList();
      curve.add({'t': i * 5, 'score': _computeDebt(inWindow)});
    }
    return curve;
  }

  // ── Demo / Dev helpers ────────────────────────────────────────────────────
  Future<void> seedDemoData() async {
    final now = DateTime.now();
    final synthetic = [
      AppSession(appName: 'Instagram', packageName: 'com.instagram.android',
          startTime: now.subtract(const Duration(minutes: 42)),
          endTime: now.subtract(const Duration(minutes: 41))),
      AppSession(appName: 'YouTube', packageName: 'com.google.android.youtube',
          startTime: now.subtract(const Duration(minutes: 41)),
          endTime: now.subtract(const Duration(minutes: 35))),
      AppSession(appName: 'WhatsApp', packageName: 'com.whatsapp',
          startTime: now.subtract(const Duration(minutes: 35)),
          endTime: now.subtract(const Duration(minutes: 34))),
      AppSession(appName: 'Lumina', packageName: 'com.lumina.lumina',
          startTime: now.subtract(const Duration(minutes: 33)),
          endTime: now.subtract(const Duration(minutes: 6))),
      AppSession(appName: 'Twitter / X', packageName: 'com.twitter.android',
          startTime: now.subtract(const Duration(minutes: 6)),
          endTime: now.subtract(const Duration(minutes: 5))),
      AppSession(appName: 'Instagram', packageName: 'com.instagram.android',
          startTime: now.subtract(const Duration(minutes: 4)),
          endTime: now.subtract(const Duration(minutes: 3))),
    ];
    final debt = _computeDebt(synthetic);
    state = AsyncData((state.value ?? const CognitiveState()).copyWith(
      timeline: synthetic,
      score: debt,
      isMonitoring: true,
      statusMessage: '✨ Demo loaded — ${synthetic.length} app switches',
    ));
    try { await ApiClient.instance.post('/demo/seed', data: {}); } catch (_) {}
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }

  // Legacy API
  Future<void> logSession({required String appName, required DateTime start, required DateTime end}) async {
    try {
      await ApiClient.instance.post('/context-switch/batch', data: {
        'sessions': [{'app_name': appName, 'session_start': start.toIso8601String(), 'session_end': end.toIso8601String()}],
      });
    } catch (_) {}
  }
}
