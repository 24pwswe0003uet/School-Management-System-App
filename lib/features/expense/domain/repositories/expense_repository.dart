import '../entities/expense.dart';
import '../entities/expense_category.dart';
import '../entities/expense_list_item.dart';
import '../entities/expense_monthly_totals.dart';
import '../entities/expense_category_total.dart';

/// Data operations for the Expense Management module.
///
/// Implementations enforce: date is required, category is required, amount > 0,
/// description is required, expense IDs are unique and human-readable.
abstract interface class ExpenseRepository {
  /// Creates a new expense record. Generates a human-readable expense_id
  /// (e.g. EXP-000001) inside a transaction.
  Future<Expense> createExpense({
    required DateTime date,
    required ExpenseCategory category,
    required double amount,
    required String description,
    String? reference,
    String? createdBy,
  });

  /// Retrieves an expense by its internal ID.
  Future<Expense?> getExpense(int id);

  /// Searches expenses with optional filters.
  ///
  /// [query] matches against expense_id, description, category, reference.
  /// [category] filters by category.
  /// [dateFrom] and [dateTo] define an inclusive date range.
  /// [year] and [month] filter by calendar month (alternative to date range).
  /// [amountMin] and [amountMax] filter by amount range.
  /// Returns up to [limit] results, ordered by date desc, id desc.
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
  });

  /// Updates an expense record. [updatedAt] is set to now; [createdAt] is
  /// immutable. Amount must be > 0.
  Future<Expense> updateExpense({
    required int id,
    required DateTime date,
    required ExpenseCategory category,
    required double amount,
    required String description,
    String? reference,
  });

  /// Deletes an expense record permanently.
  ///
  /// Callers should show a confirmation dialog before calling this.
  Future<void> deleteExpense(int id);

  /// Returns aggregated totals for a specific month.
  Future<ExpenseMonthlyTotals> monthlyTotals({
    required int year,
    required int month,
  });

  /// Returns category breakdown for a date range (inclusive).
  Future<List<ExpenseCategoryTotal>> categoryTotals({
    required DateTime from,
    required DateTime to,
  });

  /// Returns the sum of amounts for a date range (inclusive).
  Future<double> totalForDateRange({
    required DateTime from,
    required DateTime to,
  });

  /// Returns distinct years that have expense records, descending.
  Future<List<int>> distinctYears();

  /// Returns the next available human-readable expense ID (e.g. EXP-000001).
  Future<String> nextExpenseId();
}