import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/api_client.dart';

// Fetches real group name from Supabase
final groupNameProvider = FutureProvider.family<String, String>((ref, groupId) async {
  try {
    final data = await Supabase.instance.client
        .from('groups')
        .select('name')
        .eq('id', groupId)
        .single();
    return data['name'] as String? ?? 'Squad';
  } catch (_) {
    return 'Squad';
  }
});

final groupsProvider = FutureProvider<List<dynamic>>(
  (ref) => ApiClient.instance.get<List<dynamic>>('/groups'),
);

final hubProvider = StateNotifierProvider<HubNotifier, AsyncValue<void>>(
  (ref) => HubNotifier(),
);

class HubNotifier extends StateNotifier<AsyncValue<void>> {
  HubNotifier() : super(const AsyncData(null));

  Future<void> createGroup(String name, String? description, {String category = 'general'}) async {
    state = const AsyncLoading();
    try {
      await ApiClient.instance.post('/groups', data: {
        'name': name,
        'description': description,
        'category': category,
      });
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<String?> joinGroup(String inviteCode) async {
    state = const AsyncLoading();
    try {
      final res = await ApiClient.instance.post<Map<String, dynamic>>(
        '/groups/join',
        data: {'invite_code': inviteCode},
      );
      state = const AsyncData(null);
      return res['group_id'] as String?;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}
