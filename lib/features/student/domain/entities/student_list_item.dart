import 'student.dart';

/// A search result row: the student plus the family context needed to pick
/// the right record quickly (family ID, guardian, phone).
class StudentListItem {
  const StudentListItem({
    required this.student,
    required this.familyId,
    required this.guardianName,
    required this.guardianPhone,
  });

  final Student student;
  final String familyId;
  final String? guardianName;
  final String? guardianPhone;
}
