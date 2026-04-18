import 'package:flutter_riverpod/flutter_riverpod.dart';

final kanbanProvider = FutureProvider.family<List<dynamic>, String>((ref, groupId) async {
  // Kanban data is loaded directly via Supabase Realtime in KanbanScreen
  return [];
});
