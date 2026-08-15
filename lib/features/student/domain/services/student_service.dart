import 'package:flutter/foundation.dart';

import '../entities/student.dart';
import '../entities/student_details.dart';
import '../entities/student_list_item.dart';
import '../repositories/student_repository.dart';

/// Holds the student list/search state (text query + status/class/section
/// filters) and exposes student operations to the screens. Follows the
/// ChangeNotifier pattern used by the other modules.
class StudentService extends ChangeNotifier {
  StudentService(this._repository);

  final StudentRepository _repository;

  List<StudentListItem> _results = const [];
  bool _loading = false;
  Object? _error;
  String _query = '';
  StudentStatus? _statusFilter;
  String? _classFilter;
  String? _sectionFilter;
  List<String> _classes = const [];
  List<String> _sections = const [];

  List<StudentListItem> get results => _results;
  bool get isLoading => _loading;
  Object? get error => _error;
  String get query => _query;
  StudentStatus? get statusFilter => _statusFilter;
  String? get classFilter => _classFilter;
  String? get sectionFilter => _sectionFilter;
  List<String> get classes => _classes;
  List<String> get sections => _sections;

  /// Reloads the current search (or the full list when the query is empty).
  Future<void> refresh() => search(_query);

  Future<void> search(String query) async {
    _query = query;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _results = await _repository.searchStudents(
        query: query,
        status: _statusFilter,
        className: _classFilter,
        section: _sectionFilter,
      );
      if (_classes.isEmpty || _sections.isEmpty) {
        await _loadFilterOptions();
      }
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setStatusFilter(StudentStatus? status) async {
    _statusFilter = status;
    await search(_query);
  }

  Future<void> setClassFilter(String? className) async {
    _classFilter = className;
    await search(_query);
  }

  Future<void> setSectionFilter(String? section) async {
    _sectionFilter = section;
    await search(_query);
  }

  Future<void> _loadFilterOptions() async {
    _classes = await _repository.distinctClasses();
    _sections = await _repository.distinctSections();
  }

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
  }) {
    return _repository.createStudent(
      familyId: familyId,
      name: name,
      gender: gender,
      dateOfBirth: dateOfBirth,
      admissionNumber: admissionNumber,
      admissionDate: admissionDate,
      className: className,
      section: section,
      contactReference: contactReference,
      notes: notes,
      admissionFee: admissionFee,
    );
  }

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
  }) {
    return _repository.updateStudent(
      id: id,
      familyId: familyId,
      name: name,
      gender: gender,
      dateOfBirth: dateOfBirth,
      admissionNumber: admissionNumber,
      admissionDate: admissionDate,
      className: className,
      section: section,
      contactReference: contactReference,
      notes: notes,
    );
  }

  Future<Student> setStudentStatus(int id, StudentStatus status) =>
      _repository.setStudentStatus(id, status);

  Future<StudentDetails> getStudentDetails(int id) =>
      _repository.getStudentDetails(id);

  Future<List<StudentListItem>> findPossibleStudentDuplicates({
    int? excludeId,
    required String name,
    String? admissionNumber,
    int? familyId,
    String? guardianName,
    String? primaryPhone,
  }) {
    return _repository.findPossibleStudentDuplicates(
      excludeId: excludeId,
      name: name,
      admissionNumber: admissionNumber,
      familyId: familyId,
      guardianName: guardianName,
      primaryPhone: primaryPhone,
    );
  }

  Future<String> nextStudentId() => _repository.nextStudentId();

  Future<String> nextAdmissionId() => _repository.nextAdmissionId();
}
