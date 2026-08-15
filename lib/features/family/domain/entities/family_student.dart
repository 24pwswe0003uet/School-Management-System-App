/// A student linked to a family, shown on the family profile. This is the
/// minimum student data the Family module displays (the Student module builds
/// the full profile later).
class FamilyStudent {
  const FamilyStudent({
    required this.id,
    required this.studentId,
    required this.name,
    required this.className,
    required this.section,
    required this.status,
  });

  final int id;
  final String studentId;
  final String name;
  final String? className;
  final String? section;
  final String status;
}
