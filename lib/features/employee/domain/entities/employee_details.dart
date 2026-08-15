import 'employee.dart';
import 'employee_salary_record.dart';

/// The full employee profile: the record plus its salary history and a summary
/// of the money already paid out and still owed.
class EmployeeDetails {
  const EmployeeDetails({
    required this.employee,
    required this.salaryHistory,
    required this.totalPaid,
    required this.totalPending,
  });

  final Employee employee;
  final List<EmployeeSalaryRecord> salaryHistory;

  /// Sum of the net amounts of paid records.
  final double totalPaid;

  /// Sum of the net amounts of pending records.
  final double totalPending;

  int get salaryRecordCount => salaryHistory.length;
}
