import 'expense_category.dart';

/// Category total for expense reports.
class ExpenseCategoryTotal {
  const ExpenseCategoryTotal({
    required this.category,
    required this.totalAmount,
    required this.recordCount,
  });

  final ExpenseCategory category;
  final double totalAmount;
  final int recordCount;
}