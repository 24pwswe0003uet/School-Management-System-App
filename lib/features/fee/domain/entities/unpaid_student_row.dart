import 'fee_record.dart';

/// One student who has not fully paid the period — the "Students who have not
/// paid August 2026" report row.
class UnpaidStudentRow {
  const UnpaidStudentRow({
    required this.record,
    required this.studentId,
    required this.studentName,
    this.className,
    this.section,
    this.guardianName,
  });

  final FeeRecord record;
  final String studentId;
  final String studentName;
  final String? className;
  final String? section;
  final String? guardianName;
}
