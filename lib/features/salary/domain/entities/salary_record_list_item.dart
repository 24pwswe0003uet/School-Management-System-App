import 'salary_record.dart';

/// A salary record joined with its employee's display details for list rows.
class SalaryRecordListItem {
  const SalaryRecordListItem({
    required this.record,
    required this.employeeCode,
    required this.employeeName,
    required this.designation,
  });

  final SalaryRecord record;
  final String employeeCode;
  final String employeeName;
  final String? designation;
}
