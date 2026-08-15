/// A compact student snapshot used to detect duplicates during planning.
/// Loaded once so classification never requires a query per row.
class StudentDedupRecord {
  const StudentDedupRecord({
    required this.id,
    required this.studentId,
    required this.name,
    required this.familyId,
    this.admissionNumber,
    this.guardianName,
    this.primaryPhone,
    this.secondaryPhone,
  });

  final int id;
  final String studentId;
  final String name;
  final int familyId;
  final String? admissionNumber;
  final String? guardianName;
  final String? primaryPhone;
  final String? secondaryPhone;
}

/// A compact family snapshot used to match imported families against existing
/// ones via strong signals (phone/CNIC/address) — never by name alone.
class FamilyDedupRecord {
  const FamilyDedupRecord({
    required this.id,
    required this.familyId,
    required this.guardianName,
    this.motherName,
    this.primaryPhone,
    this.secondaryPhone,
    this.cnic,
    this.address,
  });

  final int id;
  final String familyId;
  final String guardianName;
  final String? motherName;
  final String? primaryPhone;
  final String? secondaryPhone;
  final String? cnic;
  final String? address;
}
