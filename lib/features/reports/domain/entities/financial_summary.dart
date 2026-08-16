/// The summary metrics for a Financial Summary report.
///
/// These values are calculated from the database using aggregate SQL queries
/// over the fee_records, payments, and salary_records tables for a selected
/// date range.
class FinancialSummary {
  const FinancialSummary({
    required this.feeIncomeCharged,
    required this.feeIncomeCollected,
    required this.salaryExpenses,
    required this.otherExpenses,
    required this.netPosition,
    required this.periodStart,
    required this.periodEnd,
  });

  /// Total fees billed/charged to students for the period.
  final double feeIncomeCharged;
  /// Total fees actually collected from payments for the period.
  final double feeIncomeCollected;
  /// Total salary expenses (paid + pending) for the period.
  final double salaryExpenses;
  /// Total other expenses (expenses module) for the period.
  final double otherExpenses;
  /// Net financial position: Fee Income - Salary Expenses - Other Expenses.
  final double netPosition;
  /// The start date of the reporting period.
  final DateTime periodStart;
  /// The end date of the reporting period.
  final DateTime periodEnd;

  /// Formatted currency string for display.
  String formatCurrency(double value) =>
      'Rs ${value.toStringAsFixed(2)}';
}