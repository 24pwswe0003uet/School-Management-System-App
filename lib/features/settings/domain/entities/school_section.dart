/// A canonical academic section (V1: one global section list, e.g. A, B, C).
///
/// Section names are unique (case-insensitive). Rows referenced by students
/// are deactivated rather than deleted. [activeStudentCount] is populated by
/// the repository so the UI can warn before deactivating.
class SchoolSection {
  const SchoolSection({
    required this.id,
    required this.sectionName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.activeStudentCount = 0,
  });

  final int id;
  final String sectionName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int activeStudentCount;
}
