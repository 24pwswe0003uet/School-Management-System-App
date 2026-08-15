import 'package:school_office_management/features/family/domain/entities/family.dart';
import 'package:school_office_management/features/student/domain/entities/admission_history_entry.dart';
import 'package:school_office_management/features/student/domain/entities/student.dart';
import 'package:school_office_management/features/student/domain/entities/student_details.dart';
import 'package:school_office_management/features/student/domain/entities/student_fee_history_item.dart';
import 'package:school_office_management/features/student/domain/entities/student_history_entry.dart';
import 'package:school_office_management/features/student/domain/entities/student_list_item.dart';
import 'package:school_office_management/features/student/domain/repositories/student_repository.dart';

import '../../family/fakes/fake_family_repository.dart';

/// In-memory [StudentRepository] for widget tests. Families are read from an
/// injected [FakeFamilyRepository] so the student search and duplicate logic
/// can include guardian/phone context the way the real SQL does.
class FakeStudentRepository implements StudentRepository {
  FakeStudentRepository({
    List<Student>? students,
    FakeFamilyRepository? familyRepository,
  }) : _students = {for (final s in students ?? <Student>[]) s.id: s},
       _familyRepository = familyRepository;

  final Map<int, Student> _students;
  final FakeFamilyRepository? _familyRepository;

  final Map<int, List<AdmissionHistoryEntry>> _admissions = {};
  final Map<int, List<StudentHistoryEntry>> _history = {};
  final Map<int, List<StudentFeeHistoryItem>> _feeHistory = {};
  final Map<int, double> _outstanding = {};

  int _nextId = 1000;
  int _nextAdmissionId = 1;

  bool failCreate = false;
  bool failSearch = false;
  bool failDetails = false;

  List<Student> get all => _students.values.toList();

  void seedAdmissions(int studentId, List<AdmissionHistoryEntry> entries) {
    _admissions[studentId] = entries;
  }

  void seedHistory(int studentId, List<StudentHistoryEntry> entries) {
    _history[studentId] = entries;
  }

  void seedFeeHistory(int studentId, List<StudentFeeHistoryItem> items) {
    _feeHistory[studentId] = items;
  }

  void seedOutstanding(int studentId, double amount) {
    _outstanding[studentId] = amount;
  }

  Family? _familyFor(int familyId) {
    final families = _familyRepository?.all ?? const <Family>[];
    for (final family in families) {
      if (family.id == familyId) return family;
    }
    return null;
  }

  String _studentIdFor(int id) =>
      'STU-${(all.length + 1).toString().padLeft(6, '0')}';

  static String _onlyDigits(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  static StudentListItem _listItem(Student student, Family? family) {
    return StudentListItem(
      student: student,
      familyId: family?.familyId ?? '',
      guardianName: family?.guardianName,
      guardianPhone: family?.primaryPhone,
    );
  }

  @override
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
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Student name is required.');
    if (_familyFor(familyId) == null) {
      throw Exception('family not found');
    }
    if (failCreate) throw Exception('simulated database failure');
    final admission = admissionNumber?.trim() ?? '';
    if (admission.isNotEmpty) {
      final taken = _students.values.any(
        (s) =>
            (s.admissionNumber ?? '').isNotEmpty &&
            s.admissionNumber!.trim().toLowerCase() == admission.toLowerCase(),
      );
      if (taken) throw Exception('duplicate admission number');
    }
    final id = _nextId++;
    final now = DateTime(2026, 8, 1);
    final student = Student(
      id: id,
      studentId: _studentIdFor(id),
      familyId: familyId,
      name: name.trim(),
      gender: gender,
      dateOfBirth: dateOfBirth,
      admissionNumber: admission.isEmpty ? null : admission,
      admissionDate: admissionDate,
      className: className,
      section: section,
      contactReference: contactReference,
      notes: notes,
      status: StudentStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    _students[id] = student;
    final admissionCode = 'ADM-${_nextAdmissionId.toString().padLeft(6, '0')}';
    _nextAdmissionId++;
    _admissions[id] = [
      AdmissionHistoryEntry(
        id: id,
        admissionId: admissionCode,
        admissionDate: admissionDate ?? now,
        className: className,
        section: section,
        admissionNumber: admission.isEmpty ? null : admission,
        admissionFee: admissionFee,
        notes: notes,
      ),
    ];
    return student;
  }

  @override
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
  }) async {
    final existing = _students[id]!;
    final updated = Student(
      id: existing.id,
      studentId: existing.studentId,
      familyId: familyId,
      name: name.trim(),
      gender: gender,
      dateOfBirth: dateOfBirth,
      admissionNumber: admissionNumber,
      admissionDate: admissionDate,
      className: className,
      section: section,
      contactReference: contactReference,
      notes: notes,
      status: existing.status,
      createdAt: existing.createdAt,
      updatedAt: DateTime(2026, 8, 2),
    );
    _students[id] = updated;
    if (existing.className != className || existing.section != section) {
      _history[id] = [
        StudentHistoryEntry(
          id: (_history[id]?.length ?? 0) + 1,
          className: className,
          section: section,
          status: existing.status.dbValue,
          changedAt: DateTime(2026, 8, 2),
        ),
        ...?_history[id],
      ];
    }
    return updated;
  }

  @override
  Future<Student> setStudentStatus(int id, StudentStatus status) async {
    final existing = _students[id]!;
    final updated = Student(
      id: existing.id,
      studentId: existing.studentId,
      familyId: existing.familyId,
      name: existing.name,
      gender: existing.gender,
      dateOfBirth: existing.dateOfBirth,
      admissionNumber: existing.admissionNumber,
      admissionDate: existing.admissionDate,
      className: existing.className,
      section: existing.section,
      contactReference: existing.contactReference,
      notes: existing.notes,
      status: status,
      createdAt: existing.createdAt,
      updatedAt: DateTime(2026, 8, 3),
    );
    _students[id] = updated;
    _history[id] = [
      StudentHistoryEntry(
        id: (_history[id]?.length ?? 0) + 1,
        className: existing.className,
        section: existing.section,
        status: status.dbValue,
        changedAt: DateTime(2026, 8, 3),
      ),
      ...?_history[id],
    ];
    return updated;
  }

  @override
  Future<Student?> getStudent(int id) async => _students[id];

  @override
  Future<Student?> getStudentByStudentId(String studentId) async {
    for (final student in _students.values) {
      if (student.studentId == studentId) return student;
    }
    return null;
  }

  @override
  Future<List<StudentListItem>> searchStudents({
    String query = '',
    StudentStatus? status,
    String? className,
    String? section,
    int limit = 100,
  }) async {
    if (failSearch) throw Exception('simulated database failure');
    final term = query.trim().toLowerCase();
    final termDigits = _onlyDigits(term);
    final results = _students.values.where((student) {
      if (status != null && student.status != status) return false;
      if (className != null && student.className != className) return false;
      if (section != null && student.section != section) return false;
      if (term.isEmpty) return true;
      final family = _familyFor(student.familyId);
      final matchesStudent =
          student.studentId.toLowerCase().contains(term) ||
          student.name.toLowerCase().contains(term) ||
          (student.admissionNumber ?? '').toLowerCase().contains(term);
      final matchesFamily =
          (family?.familyId.toLowerCase().contains(term) ?? false) ||
          (family?.guardianName.toLowerCase().contains(term) ?? false) ||
          (termDigits.isNotEmpty &&
              (_onlyDigits(family?.primaryPhone ?? '').contains(termDigits) ||
                  _onlyDigits(
                    family?.secondaryPhone ?? '',
                  ).contains(termDigits)));
      return matchesStudent || matchesFamily;
    }).toList();
    results.sort((a, b) => a.studentId.compareTo(b.studentId));
    return results
        .take(limit)
        .map((s) => _listItem(s, _familyFor(s.familyId)))
        .toList();
  }

  @override
  Future<StudentDetails> getStudentDetails(int id) async {
    if (failDetails) throw Exception('simulated database failure');
    final student = _students[id];
    if (student == null) throw ArgumentError('Student $id does not exist.');
    final family = _familyFor(student.familyId);
    if (family == null) throw ArgumentError('Family not found.');
    return StudentDetails(
      student: student,
      family: family,
      admissions: _admissions[id] ?? const [],
      history: _history[id] ?? const [],
      outstandingFees: _outstanding[id] ?? 0,
      feeHistory: _feeHistory[id] ?? const [],
    );
  }

  @override
  Future<List<StudentListItem>> findPossibleStudentDuplicates({
    int? excludeId,
    required String name,
    String? admissionNumber,
    int? familyId,
    String? guardianName,
    String? primaryPhone,
  }) async {
    final nameValue = name.trim().toLowerCase();
    final admission = admissionNumber?.trim().toLowerCase() ?? '';
    final phoneDigits = _onlyDigits(primaryPhone ?? '');
    final guardian = guardianName?.trim().toLowerCase() ?? '';
    final matches = <Student>[];
    for (final student in _students.values) {
      if (excludeId != null && student.id == excludeId) continue;
      final sameName = student.name.trim().toLowerCase() == nameValue;
      var hit = false;
      if (admission.isNotEmpty &&
          (student.admissionNumber ?? '').trim().toLowerCase() == admission) {
        hit = true;
      } else if (sameName && student.familyId == familyId) {
        hit = true;
      } else if (sameName && phoneDigits.isNotEmpty) {
        final family = _familyFor(student.familyId);
        final p1 = _onlyDigits(family?.primaryPhone ?? '');
        final p2 = _onlyDigits(family?.secondaryPhone ?? '');
        if (p1 == phoneDigits || p2 == phoneDigits) hit = true;
      } else if (sameName &&
          guardian.isNotEmpty &&
          _familyFor(student.familyId)?.guardianName.trim().toLowerCase() ==
              guardian) {
        hit = true;
      }
      if (hit) matches.add(student);
    }
    matches.sort((a, b) => a.studentId.compareTo(b.studentId));
    return matches.map((s) => _listItem(s, _familyFor(s.familyId))).toList();
  }

  @override
  Future<String> nextStudentId() async =>
      'STU-${(all.length + 1).toString().padLeft(6, '0')}';

  @override
  Future<String> nextAdmissionId() async =>
      'ADM-${_nextAdmissionId.toString().padLeft(6, '0')}';

  @override
  Future<List<String>> distinctClasses() async {
    final values = _students.values
        .map((s) => s.className)
        .where((c) => c != null && c.isNotEmpty)
        .map((c) => c!)
        .toSet();
    final list = values.toList()..sort();
    return list;
  }

  @override
  Future<List<String>> distinctSections() async {
    final values = _students.values
        .map((s) => s.section)
        .where((c) => c != null && c.isNotEmpty)
        .map((c) => c!)
        .toSet();
    final list = values.toList()..sort();
    return list;
  }
}
