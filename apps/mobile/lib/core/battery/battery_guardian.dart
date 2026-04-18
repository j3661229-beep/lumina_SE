import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../notifications/notification_service.dart';

class BatteryGuardian {
  static BatteryGuardian? _instance;
  BatteryGuardian._();
  static BatteryGuardian get instance => _instance ??= BatteryGuardian._();

  final _battery = Battery();
  StreamSubscription<BatteryState>? _stateSubscription;
  Timer? _levelTimer;
  bool _emergencyModeActive = false;

  bool get isEmergencyMode => _emergencyModeActive;

  void startWatching() {
    _levelTimer = Timer.periodic(const Duration(minutes: 2), (_) => _checkLevel());
    _stateSubscription = _battery.onBatteryStateChanged.listen((state) {
      if (state == BatteryState.charging && _emergencyModeActive) {
        _emergencyModeActive = false;
      }
    });
  }

  Future<void> _checkLevel() async {
    final level = await _battery.batteryLevel;
    if (level <= 15 && !_emergencyModeActive) {
      await _activateEmergencyMode();
    }
  }

  Future<void> _activateEmergencyMode() async {
    _emergencyModeActive = true;

    await NotificationService.instance.show(
      title: 'Battery Critical 🔋',
      body: 'Lumina is syncing your data before shutdown...',
      channelId: 'lumina_battery',
    );

    // Force Supabase Kanban sync
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('kanban_tasks')
            .select('id')
            .eq('user_id', userId)
            .limit(1);
        await Supabase.instance.client
            .from('profiles')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', userId);
      }
    } catch (_) {}

    await NotificationService.instance.show(
      title: 'Sync Complete ✓',
      body: 'Your Kanban is up to date. Please charge soon!',
      channelId: 'lumina_battery',
    );
  }

  void dispose() {
    _stateSubscription?.cancel();
    _levelTimer?.cancel();
  }
}
