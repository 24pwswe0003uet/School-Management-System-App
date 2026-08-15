import '../entities/salary_period.dart';

/// Thrown when a salary record already exists for the employee and period.
///
/// The repository checks for an existing record before inserting and the
/// UNIQUE index on `(employee_id, period_start)` enforces it at the database
/// level as a backstop.
class SalaryPeriodExistsException implements Exception {
  const SalaryPeriodExistsException({
    required this.employeeCode,
    required this.period,
  });

  final String employeeCode;
  final SalaryPeriod period;

  String get message =>
      '$employeeCode already has a record for ${period.label}.';

  @override
  String toString() => 'SalaryPeriodExistsException: $message';
}
