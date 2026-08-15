import 'salary_period.dart';

/// Aggregated salary figures for one month, computed with database SUM
/// queries rather than by loading individual records into memory.
class SalaryMonthlyTotals {
  const SalaryMonthlyTotals({
    required this.period,
    required this.recordCount,
    required this.totalBase,
    required this.totalAdvance,
    required this.totalDeduction,
    required this.totalAdjustment,
    required this.netPayable,
    required this.totalPaid,
    required this.totalPending,
  });

  final SalaryPeriod period;
  final int recordCount;

  final double totalBase;
  final double totalAdvance;
  final double totalDeduction;
  final double totalAdjustment;

  /// Sum of all net amounts for the month (paid + pending).
  final double netPayable;

  final double totalPaid;
  final double totalPending;
}
