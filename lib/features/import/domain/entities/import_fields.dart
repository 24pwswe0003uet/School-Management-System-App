/// The core student/family fields an imported workbook column can map to.
///
/// Names are never identifiers — [existingFamilyId] and [studentId] are
/// duplicate-detection / attachment keys only, never stored as identifiers.
enum ImportCoreField {
  studentName,
  gender,
  dateOfBirth,
  admissionNumber,
  admissionDate,
  className,
  section,
  admissionFee,
  contactReference,
  notes,
  guardianName,
  motherName,
  primaryPhone,
  secondaryPhone,
  address,
  cnic,
  existingFamilyId,
  studentId;

  /// Whether this field lives on the linked family record rather than the
  /// student record.
  bool get isFamilyField => switch (this) {
    ImportCoreField.guardianName ||
    ImportCoreField.motherName ||
    ImportCoreField.primaryPhone ||
    ImportCoreField.secondaryPhone ||
    ImportCoreField.address ||
    ImportCoreField.cnic => true,
    _ => false,
  };

  /// Whether this field is only used for matching (never written to the DB).
  bool get isLookupField =>
      this == ImportCoreField.existingFamilyId ||
      this == ImportCoreField.studentId;

  /// Human-readable label used in the mapping UI and export headers.
  String get displayName => switch (this) {
    ImportCoreField.studentName => 'Student Name',
    ImportCoreField.gender => 'Gender',
    ImportCoreField.dateOfBirth => 'Date of Birth',
    ImportCoreField.admissionNumber => 'Admission Number',
    ImportCoreField.admissionDate => 'Admission Date',
    ImportCoreField.className => 'Class',
    ImportCoreField.section => 'Section',
    ImportCoreField.admissionFee => 'Admission Fee',
    ImportCoreField.contactReference => 'Contact Reference',
    ImportCoreField.notes => 'Notes',
    ImportCoreField.guardianName => 'Guardian Name',
    ImportCoreField.motherName => 'Mother Name',
    ImportCoreField.primaryPhone => 'Phone',
    ImportCoreField.secondaryPhone => 'Alternate Phone',
    ImportCoreField.address => 'Address',
    ImportCoreField.cnic => 'CNIC',
    ImportCoreField.existingFamilyId => 'Existing Family ID',
    ImportCoreField.studentId => 'Student ID',
  };
}
