import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import 'ocr_parser_screen.dart';

final timetableProvider = AsyncNotifierProvider<TimetableNotifier, List<dynamic>>(
  TimetableNotifier.new,
);

class TimetableNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() => _fetchSlots();

  Future<List<dynamic>> _fetchSlots() =>
      ApiClient.instance.get<List<dynamic>>('/timetable/slots');

  Future<void> uploadSlots(List<ParsedSlot> slots) async {
    await ApiClient.instance.post('/timetable/slots', data: {
      'slots': slots.map((s) => s.toJson()).toList(),
    });
    ref.invalidateSelf();
  }

  Future<void> markAttendance(String slotId, String date, String status) async {
    await ApiClient.instance.post('/timetable/attendance', data: {
      'slot_id': slotId,
      'date': date,
      'status': status,
    });
  }
}

final bunkAnalyticsProvider = FutureProvider<List<dynamic>>(
  (ref) => ApiClient.instance.get<List<dynamic>>('/timetable/bunk-analytics'),
);
