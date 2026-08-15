import 'family.dart';
import 'family_student.dart';

/// The full family profile: family record, its linked students, and the
/// combined outstanding fees across those students.
class FamilyDetails {
  const FamilyDetails({
    required this.family,
    required this.students,
    required this.outstandingFees,
  });

  final Family family;
  final List<FamilyStudent> students;
  final double outstandingFees;

  int get studentCount => students.length;
}
