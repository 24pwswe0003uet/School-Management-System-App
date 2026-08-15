/// A student offered by the collect-payment search picker.
class FeeStudentPick {
  const FeeStudentPick({
    required this.id,
    required this.studentId,
    required this.name,
    this.className,
    this.section,
    this.guardianName,
  });

  final int id;
  final String studentId;
  final String name;
  final String? className;
  final String? section;
  final String? guardianName;
}
