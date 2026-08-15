import '../../../family/domain/entities/family.dart';
import 'admission_history_entry.dart';
import 'student.dart';
import 'student_fee_history_item.dart';
import 'student_history_entry.dart';

/// The full student profile: personal record, linked family, admission
/// history, academic change history, and fee summary (read-only until the Fee
/// module exists).
class StudentDetails {
  const StudentDetails({
    required this.student,
    required this.family,
    required this.admissions,
    required this.history,
    required this.outstandingFees,
    required this.feeHistory,
  });

  final Student student;
  final Family family;
  final List<AdmissionHistoryEntry> admissions;
  final List<StudentHistoryEntry> history;
  final double outstandingFees;
  final List<StudentFeeHistoryItem> feeHistory;
}
