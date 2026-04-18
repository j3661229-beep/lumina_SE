import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import 'ocr_parser_screen.dart';

final timetableProvider = AsyncNotifierProvider<TimetableNotifier, List<dynamic>>(
  TimetableNotifier.new,
);

class TimetableNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() => _fetchSlots();

  Future<List<dynamic>> _fetchSlots() async {
    final slots = await ApiClient.instance.get<List<dynamic>>('/timetable/slots');
    if (kDebugMode) {
      debugPrint('[Timetable] Fetched ${slots.length} slots');
      if (slots.isNotEmpty) {
        debugPrint('[Timetable] First slot keys: ${(slots.first as Map).keys.toList()}');
        debugPrint('[Timetable] First slot day_of_week: ${slots.first['day_of_week']}');
        debugPrint('[Timetable] First slot subject: ${slots.first['subject']}');
      }
    }
    return slots;
  }

  Future<void> uploadSlots(List<ParsedSlot> slots) async {
    await ApiClient.instance.post('/timetable/slots', data: {
      'slots': slots.map((s) => s.toJson()).toList(),
    });
    ref.invalidateSelf();
  }

  Future<void> deleteTimetable() async {
    await ApiClient.instance.dio.delete('/timetable');
    ref.invalidateSelf();
  }

  Future<List<ParsedSlot>> uploadTimetableImage(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final res = await ApiClient.instance.dio.post(
      '/timetable/upload-ocr',
      data: formData,
    );
    // The backend returns JSON matching { slots: [ ... ] }
    final dynamic slotsData = res.data['slots'];
    if (slotsData == null) return [];
    
    return (slotsData as List).map((s) => ParsedSlot(
      subjectName: s['subject_name'] ?? 'Unknown',
      teacher: s['teacher'],
      dayOfWeek: s['day_of_week'] ?? 'monday',
      startTime: s['start_time'] ?? '09:00',
      endTime: s['end_time'] ?? '10:00',
      slotType: s['slot_type'] ?? 'lecture',
    )).toList();
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
