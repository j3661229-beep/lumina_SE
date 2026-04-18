import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

final profileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ApiClient.instance.get<dynamic>('/profile');
  return Map<String, dynamic>.from(res ?? {});
});

class ProfileNotifier extends StateNotifier<AsyncValue<void>> {
  ProfileNotifier(this.ref) : super(const AsyncData(null));
  final Ref ref;

  Future<void> updateProfile(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      await ApiClient.instance.post('/profile/update', data: data);
      ref.invalidate(profileProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final profileActionProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<void>>((ref) {
  return ProfileNotifier(ref);
});
