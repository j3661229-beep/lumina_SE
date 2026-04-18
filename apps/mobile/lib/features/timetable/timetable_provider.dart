import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import 'timetable_models.dart';

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

  Future<void> uploadSlots({
    required List<ParsedSlot> slots,
    List<ParsedHoliday>? holidays,
    DateTime? semesterStart,
    DateTime? semesterEnd,
  }) async {
    await ApiClient.instance.post('/timetable/slots', data: {
      'slots': slots.map((s) => s.toJson()).toList(),
      if (holidays != null) 'holidays': holidays.map((h) => h.toJson()).toList(),
      if (semesterStart != null) 'semester_start': semesterStart.toIso8601String(),
      if (semesterEnd != null) 'semester_end': semesterEnd.toIso8601String(),
    });
    ref.invalidateSelf();
    ref.invalidate(bunkAnalyticsProvider);
  }

  Future<void> deleteTimetable() async {
    await ApiClient.instance.dio.delete('/timetable');
    ref.invalidateSelf();
  }

  Future<Map<String, dynamic>?> checkProfile() async {
    try {
      final res = await ApiClient.instance.get<dynamic>('/profile');
      return res as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfileAndGenerate(String division, String batch) async {
    try {
      await ApiClient.instance.post('/profile/update', data: {
        'division': division,
        'batch': batch,
      });
      await ApiClient.instance.post('/timetable/generate', data: {
        'division': division,
        'batch': batch,
      });
      ref.invalidateSelf();
    } catch (e) {
      debugPrint('[Timetable] Generation failed: $e');
    }
  }

  Future<void> updateSlot(String slotId, Map<String, dynamic> data) async {
    await ApiClient.instance.dio.put('/timetable/slots/$slotId', data: data);
    ref.invalidateSelf();
  }

  Future<void> deleteIndividualSlot(String slotId) async {
    await ApiClient.instance.dio.delete('/timetable/slots/$slotId');
    ref.invalidateSelf();
  }

  Future<OcrResult> uploadTimetableImage(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final res = await ApiClient.instance.dio.post(
      '/timetable/upload-ocr',
      data: formData,
    );

    final dynamic slotsData = res.data['slots'];
    final dynamic holidaysData = res.data['holidays'];

    final slots = (slotsData as List? ?? []).map((s) => ParsedSlot(
      subjectName: s['subject_name'] ?? 'Unknown',
      teacher: s['teacher'],
      dayOfWeek: s['day_of_week'] ?? 'monday',
      startTime: s['start_time'] ?? '09:00',
      endTime: s['end_time'] ?? '10:00',
      slotType: s['slot_type'] ?? 'lecture',
    )).toList();

    final holidays = (holidaysData as List? ?? []).map((h) => ParsedHoliday(
      name: h['name'] ?? 'Holiday',
      date: h['date'] ?? '',
    )).toList();

    return OcrResult(slots: slots, holidays: holidays);
  }

  Future<void> markAttendance(String slotId, String date, String status) async {
    await ApiClient.instance.post('/timetable/attendance', data: {
      'slot_id': slotId,
      'date': date,
      'status': status,
    });
    ref.invalidate(bunkAnalyticsProvider);
    ref.invalidate(attendanceLogsProvider);
  }
}

final attendanceLogsProvider = FutureProvider<Map<String, String>>((ref) async {
  final logs = await ApiClient.instance.get<List<dynamic>>('/timetable/attendance');
  final map = <String, String>{};
  for (var log in logs) {
    if (log['date'] == null || log['slotId'] == null) continue;
    final dateStr = (log['date'] as String).substring(0, 10); // 'yyyy-MM-dd'
    map['${log['slotId']}_$dateStr'] = log['status'] as String? ?? '';
  }
  return map;
});

final bunkAnalyticsProvider = FutureProvider<List<dynamic>>(
  (ref) => ApiClient.instance.get<List<dynamic>>('/timetable/bunk-analytics'),
);
