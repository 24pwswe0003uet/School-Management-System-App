/// One student row for the Excel export, flattened from `students`,
/// `families` and `admissions`.
class ExportStudentRow {
  const ExportStudentRow({
    required this.id,
    required this.studentId,
    required this.name,
    required this.familyId,
    this.familyIdText,
    this.gender,
    this.dateOfBirth,
    this.admissionNumber,
    this.admissionDate,
    this.className,
    this.section,
    this.admissionFee = 0,
    this.contactReference,
    this.notes,
    this.status,
    this.guardianName,
    this.motherName,
    this.primaryPhone,
    this.secondaryPhone,
    this.address,
    this.cnic,
  });

  /// Numeric DB id (used to look up custom field values).
  final int id;

  final String studentId;
  final String name;

  /// Numeric DB id of the family (used to look up custom field values).
  final int familyId;

  /// Human-readable family id (`FAM-000001`), for the export column.
  final String? familyIdText;

  final String? gender;
  final DateTime? dateOfBirth;
  final String? admissionNumber;
  final DateTime? admissionDate;
  final String? className;
  final String? section;
  final double admissionFee;
  final String? contactReference;
  final String? notes;
  final String? status;
  final String? guardianName;
  final String? motherName;
  final String? primaryPhone;
  final String? secondaryPhone;
  final String? address;
  final String? cnic;
}
