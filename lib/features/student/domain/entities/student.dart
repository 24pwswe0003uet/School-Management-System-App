/// Gender of a student, stored in the `students.gender` column.
enum StudentGender {
  male,
  female,
  other;

  String get label => switch (this) {
    StudentGender.male => 'Male',
    StudentGender.female => 'Female',
    StudentGender.other => 'Other',
  };

  static StudentGender fromDb(String value) => switch (value) {
    'male' => StudentGender.male,
    'female' => StudentGender.female,
    'other' => StudentGender.other,
    _ => StudentGender.other,
  };
}

/// Current enrolment status of a student.
enum StudentStatus {
  active,
  left,
  transferred;

  String get label => switch (this) {
    StudentStatus.active => 'Active',
    StudentStatus.left => 'Left',
    StudentStatus.transferred => 'Transferred',
  };

  String get dbValue => switch (this) {
    StudentStatus.active => 'active',
    StudentStatus.left => 'left',
    StudentStatus.transferred => 'transferred',
  };

  static StudentStatus fromDb(String? value) => switch (value) {
    'left' => StudentStatus.left,
    'transferred' => StudentStatus.transferred,
    _ => StudentStatus.active,
  };
}

/// The complete office record of one student. Names are never identifiers;
/// the unique identifier is [studentId] (e.g. `STU-000001`). Family contact
/// information lives on the linked family, not here.
class Student {
  const Student({
    required this.id,
    required this.studentId,
    required this.familyId,
    required this.name,
    required this.gender,
    required this.dateOfBirth,
    required this.admissionNumber,
    required this.admissionDate,
    required this.className,
    required this.section,
    required this.contactReference,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String studentId;
  final int familyId;
  final String name;
  final StudentGender? gender;
  final DateTime? dateOfBirth;
  final String? admissionNumber;
  final DateTime? admissionDate;
  final String? className;
  final String? section;
  final String? contactReference;
  final String? notes;
  final StudentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}
