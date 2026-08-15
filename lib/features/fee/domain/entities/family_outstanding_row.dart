/// One family's total outstanding across its students — the family
/// outstanding report row. Only families with a positive outstanding appear.
class FamilyOutstandingRow {
  const FamilyOutstandingRow({
    required this.familyId,
    required this.familyCode,
    required this.guardianName,
    required this.studentCount,
    required this.outstanding,
  });

  final int familyId;
  final String familyCode;
  final String guardianName;
  final int studentCount;
  final double outstanding;
}
