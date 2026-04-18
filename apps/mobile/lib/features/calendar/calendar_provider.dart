import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

final calendarHeatmapProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, yearMonth) async {
    final parts = yearMonth.split('-');
    final data = await ApiClient.instance.get<Map<String, dynamic>>(
      '/gmail/heatmap',
      params: {'year': parts[0], 'month': parts[1]},
    );
    return data;
  },
);
