import 'fee_record.dart';

/// A fee record joined with the student (and family) it belongs to — the rows
/// the fee-records search screen displays.
class FeeRecordListItem {
  const FeeRecordListItem({
    required this.record,
    required this.studentId,
    required this.studentName,
    this.guardianName,
    this.className,
    this.section,
  });

  final FeeRecord record;
  final String studentId;
  final String studentName;
  final String? guardianName;
  final String? className;
  final String? section;
}
