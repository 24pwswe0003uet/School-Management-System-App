import 'expense_category_total.dart';

/// Monthly expense totals for a given year/month.
class ExpenseMonthlyTotals {
  const ExpenseMonthlyTotals({
    required this.year,
    required this.month,
    required this.totalAmount,
    required this.recordCount,
    this.categoryBreakdown = const [],
  });

  final int year;
  final int month;
  final double totalAmount;
  final int recordCount;
  final List<ExpenseCategoryTotal> categoryBreakdown;

  String get periodLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[month - 1]} $year';
  }
}