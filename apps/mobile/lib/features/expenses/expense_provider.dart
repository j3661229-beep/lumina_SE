import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

final expenseProvider = AsyncNotifierProvider<ExpenseNotifier, List<dynamic>>(
  ExpenseNotifier.new,
);

class ExpenseNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() => _fetch();

  Future<List<dynamic>> _fetch() =>
      ApiClient.instance.get<List<dynamic>>('/expenses');

  Future<void> addExpense(double amount, String category, String? description) async {
    await ApiClient.instance.post('/expenses', data: {
      'amount': amount,
      'category': category,
      if (description != null) 'description': description,
    });
    ref.invalidateSelf();
  }

  Future<void> deleteExpense(String id) async {
    await ApiClient.instance.delete('/expenses/$id');
    ref.invalidateSelf();
  }
}

final weeklyWrapProvider = FutureProvider<List<dynamic>>(
  (ref) => ApiClient.instance.get<List<dynamic>>('/expenses/weekly-wrap'),
);
