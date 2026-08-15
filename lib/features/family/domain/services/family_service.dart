import 'package:flutter/foundation.dart';

import '../entities/family.dart';
import '../entities/family_details.dart';
import '../entities/family_list_item.dart';
import '../repositories/family_repository.dart';

/// Holds the family list/search state and exposes family operations to the
/// screens. Follows the ChangeNotifier pattern used by the other modules.
class FamilyService extends ChangeNotifier {
  FamilyService(this._repository);

  final FamilyRepository _repository;

  List<FamilyListItem> _results = const [];
  bool _loading = false;
  Object? _error;
  String _query = '';

  List<FamilyListItem> get results => _results;
  bool get isLoading => _loading;
  Object? get error => _error;
  String get query => _query;

  /// Reloads the current search (or the full list when the query is empty).
  Future<void> refresh() => search(_query);

  Future<void> search(String query) async {
    _query = query;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _results = await _repository.searchFamilies(query);
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Family> createFamily({
    required String guardianName,
    String? motherName,
    String? primaryPhone,
    String? secondaryPhone,
    String? address,
    String? cnic,
    String? notes,
  }) {
    return _repository.createFamily(
      guardianName: guardianName,
      motherName: motherName,
      primaryPhone: primaryPhone,
      secondaryPhone: secondaryPhone,
      address: address,
      cnic: cnic,
      notes: notes,
    );
  }

  Future<Family> updateFamily({
    required int id,
    required String guardianName,
    String? motherName,
    String? primaryPhone,
    String? secondaryPhone,
    String? address,
    String? cnic,
    String? notes,
  }) {
    return _repository.updateFamily(
      id: id,
      guardianName: guardianName,
      motherName: motherName,
      primaryPhone: primaryPhone,
      secondaryPhone: secondaryPhone,
      address: address,
      cnic: cnic,
      notes: notes,
    );
  }

  Future<Family> archiveFamily(int id) => _repository.archiveFamily(id);

  Future<Family> unarchiveFamily(int id) => _repository.unarchiveFamily(id);

  Future<void> deleteFamily(int id) => _repository.deleteFamily(id);

  Future<FamilyDetails> getFamilyDetails(int id) =>
      _repository.getFamilyDetails(id);

  /// Read-only search used by pickers (e.g. the student form). Unlike
  /// [search], this never mutates this service's state, so a picker's query
  /// cannot leak into the family list screen.
  Future<List<FamilyListItem>> findFamilies(String query, {int limit = 50}) {
    return _repository.searchFamilies(query, limit: limit);
  }

  Future<List<Family>> findPossibleDuplicates({
    int? excludeId,
    String? guardianName,
    String? motherName,
    String? primaryPhone,
    String? secondaryPhone,
    String? address,
  }) {
    return _repository.findPossibleDuplicates(
      excludeId: excludeId,
      guardianName: guardianName,
      motherName: motherName,
      primaryPhone: primaryPhone,
      secondaryPhone: secondaryPhone,
      address: address,
    );
  }

  Future<String> nextFamilyId() => _repository.nextFamilyId();
}
