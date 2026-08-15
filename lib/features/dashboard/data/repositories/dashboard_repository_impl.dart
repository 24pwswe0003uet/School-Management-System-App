import 'package:sqflite/sqflite.dart';

import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/recent_activity_item.dart';
import '../../domain/repositories/dashboard_repository.dart';

/// SQL implementation of [DashboardRepository].
///
/// All numbers come from COUNT/SUM aggregates over the domain tables created
/// in migration v2. Date boundaries are computed in Dart from the injected
/// [DateTime] and passed as parameters, keeping the queries deterministic.
class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._database);

  final Database _database;

  static const int _recentLimit = 8;

  @override
  Future<DashboardSummary> load({required DateTime now}) async {
    final today = _dateOnly(now);
    final month =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}';

    final aggregates = await _database.rawQuery(
      '''
      SELECT
        (SELECT COUNT(*) FROM students WHERE status = 'active')
          AS active_students,
        (SELECT COUNT(*) FROM families WHERE status = 'active')
          AS family_count,
        (SELECT COUNT(*) FROM employees WHERE status = 'active')
          AS active_employees,
        (SELECT COALESCE(SUM(amount), 0) FROM payments
          WHERE status = 'active' AND date(payment_date) = ?)
          AS today_collection,
        (SELECT COALESCE(SUM(amount), 0) FROM payments
          WHERE status = 'active'
            AND strftime('%Y-%m', payment_date) = ?) AS month_collection,
        (SELECT COALESCE(SUM(remaining_amount), 0) FROM fee_records
          WHERE status IN ('pending', 'partial')) AS outstanding_fees,
        (SELECT COALESCE(SUM(net_amount), 0) FROM salary_records
          WHERE status = 'paid'
            AND strftime('%Y-%m', payment_date) = ?) AS month_salary,
        (SELECT COALESCE(SUM(net_amount), 0) FROM salary_records
          WHERE status = 'pending'
            AND strftime('%Y-%m', period_start) = ?) AS month_pending_salary,
        (SELECT COALESCE(SUM(amount), 0) FROM expenses
          WHERE strftime('%Y-%m', date) = ?) AS month_expenses
    ''',
      [today, month, month, month, month],
    );

    final row = aggregates.first;

    final recentPayments = await _recentPayments();
    final recentAdmissions = await _recentAdmissions();
    final recentExpenses = await _recentExpenses();

    return DashboardSummary(
      activeStudents: _asInt(row['active_students']),
      families: _asInt(row['family_count']),
      activeEmployees: _asInt(row['active_employees']),
      todayCollection: _asDouble(row['today_collection']),
      monthCollection: _asDouble(row['month_collection']),
      outstandingFees: _asDouble(row['outstanding_fees']),
      monthSalary: _asDouble(row['month_salary']),
      monthPendingSalary: _asDouble(row['month_pending_salary']),
      monthExpenses: _asDouble(row['month_expenses']),
      recentPayments: recentPayments,
      recentAdmissions: recentAdmissions,
      recentExpenses: recentExpenses,
      asOf: now,
    );
  }

  Future<List<RecentActivityItem>> _recentPayments() async {
    final rows = await _database.rawQuery(
      '''
      SELECT payments.payment_id, payments.amount, payments.payment_date,
             students.name
      FROM payments
      JOIN students ON students.id = payments.student_id
      WHERE payments.status = 'active'
      ORDER BY payments.payment_date DESC, payments.id DESC
      LIMIT ?
    ''',
      [_recentLimit],
    );
    return rows.map((r) {
      return RecentActivityItem(
        title: r['name'] as String? ?? '',
        subtitle: 'Payment ${r['payment_id']}',
        amount: _asDouble(r['amount']),
        dateTime: _parseDate(r['payment_date']),
      );
    }).toList();
  }

  Future<List<RecentActivityItem>> _recentAdmissions() async {
    final rows = await _database.rawQuery(
      '''
      SELECT admissions.admission_id, admissions.admission_date,
             admissions.class, students.name
      FROM admissions
      JOIN students ON students.id = admissions.student_id
      ORDER BY admissions.admission_date DESC, admissions.id DESC
      LIMIT ?
    ''',
      [_recentLimit],
    );
    return rows.map((r) {
      final classText = r['class'] as String?;
      return RecentActivityItem(
        title: r['name'] as String? ?? '',
        subtitle: classText == null || classText.isEmpty
            ? 'Admission ${r['admission_id']}'
            : 'Admission ${r['admission_id']} · $classText',
        dateTime: _parseDate(r['admission_date']),
      );
    }).toList();
  }

  Future<List<RecentActivityItem>> _recentExpenses() async {
    final rows = await _database.rawQuery(
      '''
      SELECT expense_id, date, category, amount, description
      FROM expenses
      ORDER BY date DESC, id DESC
      LIMIT ?
    ''',
      [_recentLimit],
    );
    return rows.map((r) {
      final category = r['category'] as String?;
      return RecentActivityItem(
        title: category == null || category.isEmpty
            ? 'Expense ${r['expense_id']}'
            : category,
        subtitle: r['description'] as String? ?? 'Expense ${r['expense_id']}',
        amount: _asDouble(r['amount']),
        dateTime: _parseDate(r['date']),
      );
    }).toList();
  }

  static int _asInt(Object? value) => (value as num?)?.toInt() ?? 0;

  static double _asDouble(Object? value) => (value as num?)?.toDouble() ?? 0;

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
