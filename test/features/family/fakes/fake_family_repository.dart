import 'package:school_office_management/features/family/domain/entities/family.dart';
import 'package:school_office_management/features/family/domain/entities/family_details.dart';
import 'package:school_office_management/features/family/domain/entities/family_list_item.dart';
import 'package:school_office_management/features/family/domain/entities/family_student.dart';
import 'package:school_office_management/features/family/domain/repositories/family_has_linked_students_exception.dart';
import 'package:school_office_management/features/family/domain/repositories/family_repository.dart';

/// In-memory [FamilyRepository] for widget tests. Supports a simple subset of
/// the real behavior (create/update/archive/delete/search/details/duplicates)
/// without a database.
class FakeFamilyRepository implements FamilyRepository {
  FakeFamilyRepository({List<Family>? families})
    : _families = {for (final f in families ?? <Family>[]) f.id: f};

  final Map<int, Family> _families;
  final Map<int, List<FamilyStudent>> _students = {};
  final Map<int, double> _outstanding = {};

  int _nextId = 1000;

  bool failCreate = false;
  bool failSearch = false;
  bool failDetails = false;

  List<Family> get all => _families.values.toList();

  void seedStudents(int familyId, List<FamilyStudent> students) {
    _students[familyId] = students;
  }

  void seedOutstanding(int familyId, double amount) {
    _outstanding[familyId] = amount;
  }

  String _familyIdFor(int id) {
    final existing = _families[id];
    if (existing != null) return existing.familyId;
    return 'FAM-${(all.length + 1).toString().padLeft(6, '0')}';
  }

  static String _onlyDigits(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  Future<Family> createFamily({
    required String guardianName,
    String? motherName,
    String? primaryPhone,
    String? secondaryPhone,
    String? address,
    String? cnic,
    String? notes,
  }) async {
    if (guardianName.trim().isEmpty) {
      throw ArgumentError('Guardian name is required.');
    }
    if (failCreate) throw Exception('simulated database failure');
    final id = _nextId++;
    final now = DateTime(2026, 8, 1);
    final family = Family(
      id: id,
      familyId: _familyIdFor(id),
      guardianName: guardianName.trim(),
      motherName: motherName,
      primaryPhone: primaryPhone,
      secondaryPhone: secondaryPhone,
      address: address,
      cnic: cnic,
      notes: notes,
      status: FamilyStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    _families[id] = family;
    return family;
  }

  @override
  Future<Family> updateFamily({
    required int id,
    required String guardianName,
    String? motherName,
    String? primaryPhone,
    String? secondaryPhone,
    String? address,
    String? cnic,
    String? notes,
  }) async {
    final existing = _families[id]!;
    final updated = Family(
      id: existing.id,
      familyId: existing.familyId,
      guardianName: guardianName.trim(),
      motherName: motherName,
      primaryPhone: primaryPhone,
      secondaryPhone: secondaryPhone,
      address: address,
      cnic: cnic,
      notes: notes,
      status: existing.status,
      createdAt: existing.createdAt,
      updatedAt: DateTime(2026, 8, 2),
    );
    _families[id] = updated;
    return updated;
  }

  @override
  Future<Family> archiveFamily(int id) async =>
      _families[id] = _families[id]!.copyWith(status: FamilyStatus.inactive);

  @override
  Future<Family> unarchiveFamily(int id) async =>
      _families[id] = _families[id]!.copyWith(status: FamilyStatus.active);

  @override
  Future<void> deleteFamily(int id) async {
    final family = _families[id];
    if (family == null) return;
    if ((_students[id] ?? const <FamilyStudent>[]).isNotEmpty) {
      throw FamilyHasLinkedStudentsException(family.familyId);
    }
    _families.remove(id);
  }

  @override
  Future<Family?> getFamily(int id) async => _families[id];

  @override
  Future<Family?> getFamilyByFamilyId(String familyId) async {
    for (final family in _families.values) {
      if (family.familyId == familyId) return family;
    }
    return null;
  }

  @override
  Future<List<FamilyListItem>> searchFamilies(
    String query, {
    int limit = 50,
  }) async {
    if (failSearch) throw Exception('simulated database failure');
    final term = query.trim().toLowerCase();
    final termDigits = _onlyDigits(term);
    final results = _families.values.where((family) {
      if (term.isEmpty) return true;
      final matchesName =
          family.guardianName.toLowerCase().contains(term) ||
          (family.motherName ?? '').toLowerCase().contains(term);
      final matchesId = family.familyId.toLowerCase().contains(term);
      final matchesPhone =
          termDigits.isNotEmpty &&
          ((family.primaryPhone ?? '')
                  .replaceAll(RegExp(r'[^0-9]'), '')
                  .contains(termDigits) ||
              (family.secondaryPhone ?? '')
                  .replaceAll(RegExp(r'[^0-9]'), '')
                  .contains(termDigits));
      final matchesStudent =
          _students[family.id]?.any(
            (s) => s.name.toLowerCase().contains(term),
          ) ??
          false;
      return matchesName || matchesId || matchesPhone || matchesStudent;
    }).toList();
    results.sort((a, b) => a.familyId.compareTo(b.familyId));
    return results
        .map(
          (f) => FamilyListItem(
            family: f,
            studentCount: _students[f.id]?.length ?? 0,
          ),
        )
        .toList();
  }

  @override
  Future<List<Family>> findPossibleDuplicates({
    int? excludeId,
    String? guardianName,
    String? motherName,
    String? primaryPhone,
    String? secondaryPhone,
    String? address,
  }) async {
    final guardian = (guardianName ?? '').trim().toLowerCase();
    final mother = (motherName ?? '').trim().toLowerCase();
    final phone1 = (primaryPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final phone2 = (secondaryPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final addressQ = (address ?? '').trim().toLowerCase();
    final results = _families.values.where((family) {
      if (excludeId != null && family.id == excludeId) return false;
      final fGuardian = family.guardianName.toLowerCase();
      final fMother = (family.motherName ?? '').toLowerCase();
      final fAddress = (family.address ?? '').toLowerCase();
      final p1 = (family.primaryPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      final p2 = (family.secondaryPhone ?? '').replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      return (guardian.isNotEmpty && fGuardian.contains(guardian)) ||
          (mother.isNotEmpty && fMother.contains(mother)) ||
          (phone1.isNotEmpty && (p1 == phone1 || p2 == phone1)) ||
          (phone2.isNotEmpty && (p1 == phone2 || p2 == phone2)) ||
          (addressQ.isNotEmpty && fAddress.contains(addressQ));
    }).toList();
    results.sort((a, b) => a.familyId.compareTo(b.familyId));
    return results;
  }

  @override
  Future<FamilyDetails> getFamilyDetails(int id) async {
    if (failDetails) throw Exception('simulated database failure');
    final family = _families[id];
    if (family == null) throw ArgumentError('Family $id does not exist.');
    return FamilyDetails(
      family: family,
      students: _students[id] ?? const <FamilyStudent>[],
      outstandingFees: _outstanding[id] ?? 0,
    );
  }

  @override
  Future<String> nextFamilyId() async {
    return 'FAM-${(all.length + 1).toString().padLeft(6, '0')}';
  }
}
