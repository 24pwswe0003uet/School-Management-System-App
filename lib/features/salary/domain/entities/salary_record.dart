import 'salary_period.dart';
import 'salary_status.dart';

/// A monthly salary transaction for an employee.
///
/// The employee is referenced by [employeeId] (the `employees` primary key);
/// name and EMP code are always resolved through a JOIN, never duplicated onto
/// the record. [netAmount] is always derived by the salary calculator from the
/// components — it is never entered or edited by hand.
class SalaryRecord {
  const SalaryRecord({
    required this.id,
    required this.salaryRecordId,
    required this.employeeId,
    required this.period,
    required this.baseSalary,
    required this.advance,
    required this.deduction,
    required this.otherAdjustment,
    required this.netAmount,
    required this.paymentDate,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String salaryRecordId;
  final int employeeId;
  final SalaryPeriod period;
  final double baseSalary;
  final double advance;
  final double deduction;
  final double otherAdjustment;
  final double netAmount;
  final DateTime? paymentDate;
  final SalaryStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPaid => status == SalaryStatus.paid;
}
