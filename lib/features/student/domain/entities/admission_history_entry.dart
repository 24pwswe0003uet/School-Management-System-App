/// One admission event for a student, kept in the `admissions` table. The
/// Admission module writes the full record (number, fee, notes) when a student
/// is admitted; older rows may have nulls for the newer fields.
class AdmissionHistoryEntry {
  const AdmissionHistoryEntry({
    required this.id,
    required this.admissionId,
    required this.admissionDate,
    required this.className,
    required this.section,
    this.admissionNumber,
    this.admissionFee,
    this.notes,
  });

  final int id;
  final String admissionId;
  final DateTime admissionDate;
  final String? className;
  final String? section;

  /// The school's own admission number at the time of admission (snapshot).
  final String? admissionNumber;

  /// The admission fee charged on admission, if any.
  final double? admissionFee;

  final String? notes;
}
