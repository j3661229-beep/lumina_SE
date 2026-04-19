import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceState {
  final Set<String> onlineUserIds;
  final Set<String> typingUserIds;
  final Map<String, String> idToName;

  PresenceState({
    this.onlineUserIds = const {},
    this.typingUserIds = const {},
    this.idToName = const {},
  });

  PresenceState copyWith({
    Set<String>? onlineUserIds,
    Set<String>? typingUserIds,
    Map<String, String>? idToName,
  }) {
    return PresenceState(
      onlineUserIds: onlineUserIds ?? this.onlineUserIds,
      typingUserIds: typingUserIds ?? this.typingUserIds,
      idToName: idToName ?? this.idToName,
    );
  }
}

class PresenceNotifier extends FamilyNotifier<PresenceState, String> {
  RealtimeChannel? _channel;
  Timer? _typingTimer;

  @override
  PresenceState build(String arg) {
    _initPresence(arg);
    ref.onDispose(() {
      _channel?.unsubscribe();
      _typingTimer?.cancel();
    });
    return PresenceState();
  }

  void _initPresence(String groupId) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final displayName = user.userMetadata?['display_name'] ?? user.email?.split('@')[0] ?? 'User';

    _channel = supabase.channel('presence:$groupId');

    _channel!
        .onPresenceSync((payload) {
          final presenceState = _channel!.presenceState();
          final onlineIds = <String>{};
          final typingIds = <String>{};
          final names = <String, String>{};

          for (final pres in presenceState) {
            final dynamic p = pres;
            // In some versions of the client, the payload is nested or flattened
            final payload = p.payload ?? p; 
            final id = payload['user_id'] as String?;
            final name = payload['name'] as String?;
            final isTyping = payload['typing'] == true;

            if (id != null && name != null) {
              onlineIds.add(id);
              names[id] = name;
              if (isTyping && id != user.id) {
                typingIds.add(id);
              }
            }
          }

          state = state.copyWith(
            onlineUserIds: onlineIds,
            typingUserIds: typingIds,
            idToName: names,
          );
        })
        .subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _channel!.track({
          'user_id': user.id,
          'name': displayName,
          'typing': false,
        });
      }
    });
  }

  void setTyping(bool typing) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _channel == null) return;

    final displayName = user.userMetadata?['display_name'] ?? user.email?.split('@')[0] ?? 'User';

    _channel!.track({
      'user_id': user.id,
      'name': displayName,
      'typing': typing,
    });

    if (typing) {
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        setTyping(false);
      });
    }
  }
}

final presenceProvider = NotifierProvider.family<PresenceNotifier, PresenceState, String>(() {
  return PresenceNotifier();
});
