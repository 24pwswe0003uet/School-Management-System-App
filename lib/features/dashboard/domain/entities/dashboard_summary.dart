import 'recent_activity_item.dart';

/// Snapshot of the numbers shown on the dashboard, all derived from the local
/// SQLite database. Nothing on the dashboard is hard-coded or fabricated.
class DashboardSummary {
  const DashboardSummary({
    required this.activeStudents,
    required this.families,
    required this.activeEmployees,
    required this.todayCollection,
    required this.monthCollection,
    required this.outstandingFees,
    required this.monthSalary,
    required this.monthPendingSalary,
    required this.monthExpenses,
    required this.recentPayments,
    required this.recentAdmissions,
    required this.recentExpenses,
    required this.asOf,
  });

  final int activeStudents;
  final int families;
  final int activeEmployees;

  final double todayCollection;
  final double monthCollection;
  final double outstandingFees;
  final double monthSalary;
  final double monthPendingSalary;
  final double monthExpenses;

  final List<RecentActivityItem> recentPayments;
  final List<RecentActivityItem> recentAdmissions;
  final List<RecentActivityItem> recentExpenses;

  /// Local time the summary was computed at.
  final DateTime asOf;

  /// True when there is no data at all, so the UI can explain the zeros
  /// instead of showing a wall of "Rs 0" without context.
  bool get isEmpty =>
      activeStudents == 0 &&
      families == 0 &&
      activeEmployees == 0 &&
      todayCollection == 0 &&
      monthCollection == 0 &&
      outstandingFees == 0 &&
      monthSalary == 0 &&
      monthPendingSalary == 0 &&
      monthExpenses == 0 &&
      recentPayments.isEmpty &&
      recentAdmissions.isEmpty &&
      recentExpenses.isEmpty;

  static final DashboardSummary empty = DashboardSummary(
    activeStudents: 0,
    families: 0,
    activeEmployees: 0,
    todayCollection: 0,
    monthCollection: 0,
    outstandingFees: 0,
    monthSalary: 0,
    monthPendingSalary: 0,
    monthExpenses: 0,
    recentPayments: [],
    recentAdmissions: [],
    recentExpenses: [],
    asOf: DateTime.fromMillisecondsSinceEpoch(0),
  );
}
