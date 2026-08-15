import '../entities/student.dart';
import '../entities/student_details.dart';
import '../entities/student_list_item.dart';

/// Data operations for the Student Management module.
///
/// Implementations enforce: student name is required, student IDs are unique,
/// a student always belongs to an existing family (foreign keys), admission
/// numbers are unique when used, and class/section/status changes append to
/// `student_history` instead of overwriting. Students are never hard-deleted —
/// the office changes their status instead.
abstract interface class StudentRepository {
  /// Creates a student linked to [familyId] and records its initial admission
  /// in the `admissions` table (same transaction). The admission row carries
  /// the admission number, date, class, section, an optional [admissionFee]
  /// and [notes]. Throws a `DatabaseException` when [familyId] does not exist
  /// or the admission number is already used; on failure the whole transaction
  /// is rolled back.
  Future<Student> createStudent({
    required int familyId,
    required String name,
    StudentGender? gender,
    DateTime? dateOfBirth,
    String? admissionNumber,
    DateTime? admissionDate,
    String? className,
    String? section,
    String? contactReference,
    String? notes,
    double admissionFee = 0,
  });

  Future<Student> updateStudent({
    required int id,
    required int familyId,
    required String name,
    StudentGender? gender,
    DateTime? dateOfBirth,
    String? admissionNumber,
    DateTime? admissionDate,
    String? className,
    String? section,
    String? contactReference,
    String? notes,
  });

  /// Changes the student's status and appends a [StudentHistoryEntry].
  Future<Student> setStudentStatus(int id, StudentStatus status);

  Future<Student?> getStudent(int id);

  Future<Student?> getStudentByStudentId(String studentId);

  /// Fast, indexed search. Every condition is pushed into SQL with a LIMIT so
  /// the whole table is never loaded into memory.
  Future<List<StudentListItem>> searchStudents({
    String query = '',
    StudentStatus? status,
    String? className,
    String? section,
    int limit = 100,
  });

  Future<StudentDetails> getStudentDetails(int id);

  /// Possible duplicates of the incoming student. Matches on admission number,
  /// name + same family, name + guardian phone, and name + guardian name.
  /// Name-only matches are intentionally excluded — a shared name never
  /// rejects a new student.
  Future<List<StudentListItem>> findPossibleStudentDuplicates({
    int? excludeId,
    required String name,
    String? admissionNumber,
    int? familyId,
    String? guardianName,
    String? primaryPhone,
  });

  /// The next available generated ID, e.g. `STU-000002`.
  Future<String> nextStudentId();

  /// The next available admission record ID, e.g. `ADM-000002`. Used to
  /// pre-fill the admission number field in the admission wizard.
  Future<String> nextAdmissionId();

  Future<List<String>> distinctClasses();

  Future<List<String>> distinctSections();
}
