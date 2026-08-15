import '../entities/salary_employee_pick.dart';
import '../entities/salary_monthly_totals.dart';
import '../entities/salary_period.dart';
import '../entities/salary_record.dart';
import '../entities/salary_record_list_item.dart';
import '../entities/salary_status.dart';

/// Data operations for the Salary Management module.
///
/// Implementations guarantee: net amounts are always derived from the
/// components through the shared salary calculator; an employee has at most
/// one record per month (checked before insert and enforced by a UNIQUE
/// index); employee identity is never duplicated — names and EMP codes come
/// from a JOIN on `employees`; money uses the app-wide double + round-to-2
/// convention.
abstract interface class SalaryRepository {
  /// Creates a monthly salary record. Throws [SalaryPeriodExistsException]
  /// when the employee already has a record for [period]. Runs in a
  /// transaction so a failed insert never leaves partial data.
  Future<SalaryRecord> createSalary({
    required int employeeId,
    required SalaryPeriod period,
    required double baseSalary,
    required double advance,
    required double deduction,
    required double otherAdjustment,
    required SalaryStatus status,
    DateTime? paymentDate,
    String? notes,
  });

  /// Updates the components/status of a record, recomputing the net amount.
  /// [createdAt] is preserved; [updatedAt] is refreshed.
  Future<SalaryRecord> updateSalary({
    required int id,
    required double baseSalary,
    required double advance,
    required double deduction,
    required double otherAdjustment,
    required SalaryStatus status,
    DateTime? paymentDate,
    String? notes,
  });

  /// Marks a record as Paid, recording the payment date. Amounts never change.
  Future<SalaryRecord> markPaid({
    required int id,
    required DateTime paymentDate,
  });

  /// Deletes a salary record. The UI only offers this for Pending records and
  /// behind a strong confirmation; the repository performs a plain delete.
  Future<void> deleteSalary(int id);

  Future<SalaryRecord?> getSalaryRecord(int id);

  /// A single record joined with its employee display details.
  Future<SalaryRecordListItem?> getSalaryRecordDetails(int id);

  Future<SalaryRecord?> getSalaryForPeriod(int employeeId, SalaryPeriod period);

  Future<List<SalaryRecord>> salaryHistoryForEmployee(int employeeId);

  Future<List<SalaryRecordListItem>> searchSalaries({
    String query,
    SalaryPeriod? period,
    SalaryStatus? status,
    int? year,
    int? employeeId,
  });

  /// Aggregated salary figures for a month, via database SUM queries.
  Future<SalaryMonthlyTotals> monthlyTotals({
    required int year,
    required int month,
  });

  /// Active employees whose name or EMP code matches, for the salary form
  /// picker (includes the current basic salary for prefill).
  Future<List<SalaryEmployeePick>> searchEmployees(
    String query, {
    int limit = 20,
  });

  /// Distinct years present in salary records, for the year filter.
  Future<List<int>> distinctYears();
}
