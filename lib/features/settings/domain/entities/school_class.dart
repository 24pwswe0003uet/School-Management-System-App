/// A canonical academic class managed in School Settings.
///
/// Class names are unique (case-insensitive). Rows referenced by students are
/// deactivated rather than deleted. [activeStudentCount] is populated by the
/// repository so the UI can warn before deactivating or renaming.
class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.className,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.activeStudentCount = 0,
  });

  final int id;
  final String className;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int activeStudentCount;

  SchoolClass copyWith({
    String? className,
    bool? isActive,
    DateTime? updatedAt,
    int? activeStudentCount,
  }) {
    return SchoolClass(
      id: id,
      className: className ?? this.className,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      activeStudentCount: activeStudentCount ?? this.activeStudentCount,
    );
  }
}
