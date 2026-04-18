import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';

final budgetProvider = NotifierProvider<BudgetNotifier, double>(BudgetNotifier.new);

class BudgetNotifier extends Notifier<double> {
  @override
  double build() { _load(); return 5000.0; }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble('weekly_budget') ?? 5000.0;
  }
  Future<void> setBudget(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('weekly_budget', value);
    state = value;
  }
}

// Primary provider (renamed alias for consistency)
final expensesProvider = AsyncNotifierProvider<ExpenseNotifier, List<dynamic>>(
  ExpenseNotifier.new,
);

// Legacy alias
final expenseProvider = expensesProvider;

class ExpenseNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() => ApiClient.instance.get<List<dynamic>>('/expenses');

  Future<void> add(Map<String, dynamic> data) async {
    await ApiClient.instance.post('/expenses', data: data);
    ref.invalidateSelf();
  }

  Future<void> updateRecord(dynamic id, Map<String, dynamic> data) async {
    await ApiClient.instance.put('/expenses/$id', data: data);
    ref.invalidateSelf();
  }

  Future<void> delete(dynamic id) async {
    await ApiClient.instance.delete('/expenses/$id');
    ref.invalidateSelf();
  }

  // Legacy methods kept for backward compatibility
  Future<void> addExpense(double amount, String category, String? description) =>
      add({'amount': amount, 'category': category, if (description != null) 'description': description});

  Future<void> updateExpense(String id, double amount, String category, String? description) =>
      updateRecord(id, {'amount': amount, 'category': category, if (description != null) 'description': description});

  Future<void> deleteExpense(String id) => delete(id);
}

final weeklyWrapProvider = FutureProvider<List<dynamic>>(
  (ref) => ApiClient.instance.get<List<dynamic>>('/expenses/weekly-wrap'),
);
