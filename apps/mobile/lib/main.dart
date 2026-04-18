import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/network/api_client.dart';
import 'core/notifications/notification_service.dart';
import 'core/battery/battery_guardian.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://vpcejyrodoibjofpxhrq.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwY2VqeXJvZG9pYmpvZnB4aHJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0NjM0ODYsImV4cCI6MjA5MjAzOTQ4Nn0.GGzplMSupyzLQLedc74Mrxa3eTC7cVG6wNlhzbWeZPg',
    ),
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
      autoRefreshToken: true,
    ),
  );

  // ── Ensure backend Profile row exists after every sign-in ──────────────────
  // This fires for both email login AND Google OAuth, creating the Prisma
  // Profile row that all FK-constrained tables depend on.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    if (data.event == AuthChangeEvent.signedIn) {
      try {
        await ApiClient.instance.post('/auth/ensure-profile', data: {});
      } catch (_) {
        // Non-fatal — features degrade gracefully if profile upsert fails
      }
    }
  });

  await Hive.initFlutter();
  await NotificationService.instance.init();

  runApp(
    const ProviderScope(
      child: LuminaApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    BatteryGuardian.instance.startWatching();
  });
}
