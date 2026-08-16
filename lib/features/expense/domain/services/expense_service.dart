import 'package:flutter/foundation.dart';

import '../entities/expense.dart';
import '../entities/expense_category.dart';
import '../entities/expense_list_item.dart';
import '../entities/expense_monthly_totals.dart';
import '../entities/expense_category_total.dart';
import '../repositories/expense_repository.dart';

/// Holds the expense list/search state and exposes expense operations to the
/// screens. Follows the ChangeNotifier pattern used by the other modules.
class ExpenseService extends ChangeNotifier {
  ExpenseService(this._repository);

  final ExpenseRepository _repository;

  List<ExpenseListItem> _results = const [];
  bool _loading = false;
  Object? _error;
  String _query = '';
  ExpenseCategory? _categoryFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int? _yearFilter;
  int? _monthFilter;
  double? _amountMin;
  double? _amountMax;

  List<ExpenseListItem> get results => _results;
  bool get isLoading => _loading;
  Object? get error => _error;
  String get query => _query;
  ExpenseCategory? get categoryFilter => _categoryFilter;
  DateTime? get dateFrom => _dateFrom;
  DateTime? get dateTo => _dateTo;
  int? get yearFilter => _yearFilter;
  int? get monthFilter => _monthFilter;
  double? get amountMin => _amountMin;
  double? get amountMax => _amountMax;

  bool get hasFilters =>
      _categoryFilter != null ||
      _dateFrom != null ||
      _dateTo != null ||
      _yearFilter != null ||
      _monthFilter != null ||
      _amountMin != null ||
      _amountMax != null;

  Future<void> refresh() => search(_query);

  Future<List<ExpenseListItem>> searchExpenses({
    required String query,
    ExpenseCategory? category,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? year,
    int? month,
    double? amountMin,
    double? amountMax,
  }) {
    return _repository.searchExpenses(
      query: query,
      category: category,
      dateFrom: dateFrom,
      dateTo: dateTo,
      year: year,
      month: month,
      amountMin: amountMin,
      amountMax: amountMax,
    );
  }

  Future<void> search(String query) async {
    _query = query;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _results = await _repository.searchExpenses(
        query: query,
        category: _categoryFilter,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        year: _yearFilter,
        month: _monthFilter,
        amountMin: _amountMin,
        amountMax: _amountMax,
      );
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setCategoryFilter(ExpenseCategory? category) {
    _categoryFilter = category;
    search(_query);
  }

  void setDateRange(DateTime? from, DateTime? to) {
    _dateFrom = from;
    _dateTo = to;
    search(_query);
  }

  void setYearFilter(int? year) {
    _yearFilter = year;
    search(_query);
  }

  void setMonthFilter(int? month) {
    _monthFilter = month;
    search(_query);
  }

  void setAmountRange(double? min, double? max) {
    _amountMin = min;
    _amountMax = max;
    search(_query);
  }

  void clearFilters() {
    _categoryFilter = null;
    _dateFrom = null;
    _dateTo = null;
    _yearFilter = null;
    _monthFilter = null;
    _amountMin = null;
    _amountMax = null;
    search(_query);
  }

  // Operations -----------------------------------------------------------

  Future<Expense> createExpense({
    required DateTime date,
    required ExpenseCategory category,
    required double amount,
    required String description,
    String? reference,
    String? createdBy,
  }) {
    return _repository.createExpense(
      date: date,
      category: category,
      amount: amount,
      description: description,
      reference: reference,
      createdBy: createdBy,
    );
  }

  Future<Expense> updateExpense({
    required int id,
    required DateTime date,
    required ExpenseCategory category,
    required double amount,
    required String description,
    String? reference,
  }) {
    return _repository.updateExpense(
      id: id,
      date: date,
      category: category,
      amount: amount,
      description: description,
      reference: reference,
    );
  }

  Future<void> deleteExpense(int id) => _repository.deleteExpense(id);

  Future<ExpenseMonthlyTotals> monthlyTotals({
    required int year,
    required int month,
  }) =>
      _repository.monthlyTotals(year: year, month: month);

  Future<List<ExpenseCategoryTotal>> categoryTotals({
    required DateTime from,
    required DateTime to,
  }) =>
      _repository.categoryTotals(from: from, to: to);

  Future<double> totalForDateRange({
    required DateTime from,
    required DateTime to,
  }) =>
      _repository.totalForDateRange(from: from, to: to);

  Future<List<int>> distinctYears() => _repository.distinctYears();

  Future<String> nextExpenseId() => _repository.nextExpenseId();
}