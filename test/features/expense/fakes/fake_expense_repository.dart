import 'package:school_office_management/features/expense/domain/entities/expense.dart';
import 'package:school_office_management/features/expense/domain/entities/expense_category.dart';
import 'package:school_office_management/features/expense/domain/entities/expense_category_total.dart';
import 'package:school_office_management/features/expense/domain/entities/expense_list_item.dart';
import 'package:school_office_management/features/expense/domain/entities/expense_monthly_totals.dart';
import 'package:school_office_management/features/expense/domain/repositories/expense_repository.dart';

class FakeExpenseRepository implements ExpenseRepository {
  FakeExpenseRepository({List<Expense>? expenses})
      : _expenses = {for (final e in expenses ?? <Expense>[]) e.id: e};

  final Map<int, Expense> _expenses;
  int _nextId = 1000;
  int _nextExpenseCode = 1;

  bool failCreate = false;
  bool failSearch = false;

  String _nextExpenseId() =>
      'EXP-${_nextExpenseCode.toString().padLeft(6, '0')}';

  List<Expense> get all => _expenses.values.toList();

  @override
  Future<Expense> createExpense({
    required DateTime date,
    required ExpenseCategory category,
    required double amount,
    required String description,
    String? reference,
    String? createdBy,
  }) async {
    if (description.trim().isEmpty) {
      throw ArgumentError('Description is required.');
    }
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }
    if (failCreate) throw Exception('simulated database failure');
    final id = _nextId++;
    final now = DateTime(2026, 8, 1);
    final expense = Expense(
      id: id,
      expenseId: _nextExpenseId(),
      date: date,
      category: category.dbValue,
      amount: amount,
      description: description,
      reference: reference,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );
    _nextExpenseCode++;
    _expenses[id] = expense;
    return expense;
  }

  @override
  Future<void> deleteExpense(int id) async {
    _expenses.remove(id);
  }

  @override
  Future<Expense?> getExpense(int id) async => _expenses[id];

  @override
  Future<List<ExpenseListItem>> searchExpenses({
    String query = '',
    ExpenseCategory? category,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? year,
    int? month,
    double? amountMin,
    double? amountMax,
    int limit = 200,
  }) async {
    if (failSearch) throw Exception('simulated database failure');
    final term = query.trim().toLowerCase();
    var results = _expenses.values.where((expense) {
      if (term.isNotEmpty &&
          !expense.expenseId.toLowerCase().contains(term) &&
          !(expense.description?.toLowerCase().contains(term) ?? false) &&
          !expense.category.toLowerCase().contains(term) &&
          !(expense.reference?.toLowerCase().contains(term) ?? false)) {
        return false;
      }
      if (category != null && expense.category != category.dbValue) return false;
      if (dateFrom != null && expense.date.isBefore(dateFrom)) return false;
      if (dateTo != null && expense.date.isAfter(dateTo)) return false;
      if (year != null && expense.date.year != year) return false;
      if (month != null && expense.date.month != month) return false;
      if (amountMin != null && expense.amount < amountMin) return false;
      if (amountMax != null && expense.amount > amountMax) return false;
      return true;
    }).toList();
    results.sort((a, b) => b.date.compareTo(a.date) != 0
        ? b.date.compareTo(a.date)
        : b.id.compareTo(a.id));
    return results
        .take(limit)
        .map((e) => ExpenseListItem(expense: e, createdByName: e.createdBy))
        .toList();
  }

  @override
  Future<Expense> updateExpense({
    required int id,
    required DateTime date,
    required ExpenseCategory category,
    required double amount,
    required String description,
    String? reference,
  }) async {
    final existing = _expenses[id];
    if (existing == null) throw ArgumentError('Expense $id does not exist.');
    final updated = Expense(
      id: existing.id,
      expenseId: existing.expenseId,
      date: date,
      category: category.dbValue,
      amount: amount,
      description: description,
      reference: reference,
      createdBy: existing.createdBy,
      createdAt: existing.createdAt,
      updatedAt: DateTime(2026, 8, 2),
    );
    _expenses[id] = updated;
    return updated;
  }

  @override
  Future<ExpenseMonthlyTotals> monthlyTotals({
    required int year,
    required int month,
  }) async {
    final matching = _expenses.values
        .where((e) => e.date.year == year && e.date.month == month)
        .toList();
    final total = matching.fold<double>(0, (sum, e) => sum + e.amount);
    final categoryTotals = <ExpenseCategory, double>{};
    final categoryCounts = <ExpenseCategory, int>{};
    for (final e in matching) {
      final cat = ExpenseCategory.fromDb(e.category);
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }
    return ExpenseMonthlyTotals(
      year: year,
      month: month,
      totalAmount: total,
      recordCount: matching.length,
      categoryBreakdown: categoryTotals.entries
          .map((e) => ExpenseCategoryTotal(
              category: e.key,
              totalAmount: e.value,
              recordCount: categoryCounts[e.key] ?? 0))
          .toList(),
    );
  }

  @override
  Future<List<ExpenseCategoryTotal>> categoryTotals({
    required DateTime from,
    required DateTime to,
  }) async {
    final matching = _expenses.values
        .where((e) =>
            !e.date.isBefore(from) && !e.date.isAfter(to))
        .toList();
    final categoryTotals = <ExpenseCategory, double>{};
    final categoryCounts = <ExpenseCategory, int>{};
    for (final e in matching) {
      final cat = ExpenseCategory.fromDb(e.category);
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }
    return categoryTotals.entries
        .map((e) => ExpenseCategoryTotal(
            category: e.key,
            totalAmount: e.value,
            recordCount: categoryCounts[e.key] ?? 0))
        .toList();
  }

  @override
  Future<double> totalForDateRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final matching = _expenses.values
        .where((e) => !e.date.isBefore(from) && !e.date.isAfter(to))
        .toList();
    return matching.fold<double>(0, (sum, e) => sum + e.amount);
  }

  @override
  Future<List<int>> distinctYears() async {
    final years = _expenses.values.map((e) => e.date.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
  }

  @override
  Future<String> nextExpenseId() async => _nextExpenseId();
}
