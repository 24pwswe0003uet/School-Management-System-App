/// One class/section/status change for a student. History is never overwritten:
/// every change appends a new row so the full progression is preserved.
class StudentHistoryEntry {
  const StudentHistoryEntry({
    required this.id,
    required this.className,
    required this.section,
    required this.status,
    required this.changedAt,
  });

  final int id;
  final String? className;
  final String? section;
  final String? status;
  final DateTime changedAt;
}
