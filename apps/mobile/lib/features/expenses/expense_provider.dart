import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';

final budgetProvider = NotifierProvider<BudgetNotifier, double>(BudgetNotifier.new);

class BudgetNotifier extends Notifier<double> {
  @override
  double build() {
    _load();
    return 5000.0;
  }

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

  Future<void> updateExpense(String id, double amount, String category, String? description) async {
    await ApiClient.instance.put('/expenses/$id', data: {
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
