import '../entities/family.dart';
import '../entities/family_details.dart';
import '../entities/family_list_item.dart';

/// Data operations for the Family Management module.
///
/// Implementations enforce: guardian name is required, family IDs are unique,
/// families with linked students cannot be deleted (only archived), and
/// students can never reference a family that does not exist.
abstract interface class FamilyRepository {
  Future<Family> createFamily({
    required String guardianName,
    String? motherName,
    String? primaryPhone,
    String? secondaryPhone,
    String? address,
    String? cnic,
    String? notes,
  });

  Future<Family> updateFamily({
    required int id,
    required String guardianName,
    String? motherName,
    String? primaryPhone,
    String? secondaryPhone,
    String? address,
    String? cnic,
    String? notes,
  });

  Future<Family> archiveFamily(int id);

  Future<Family> unarchiveFamily(int id);

  /// Permanently deletes an empty family. Throws
  /// [FamilyHasLinkedStudentsException] when students reference the family.
  Future<void> deleteFamily(int id);

  Future<Family?> getFamily(int id);

  Future<Family?> getFamilyByFamilyId(String familyId);

  /// Searches by family ID, guardian name, mother name, phone, or a linked
  /// student's name. Results include the student count for disambiguation.
  Future<List<FamilyListItem>> searchFamilies(String query, {int limit = 50});

  /// Finds families that may be duplicates of the given data, using guardian
  /// name, phones, and address. Never auto-merges — callers show the list and
  /// let the operator decide.
  Future<List<Family>> findPossibleDuplicates({
    int? excludeId,
    String? guardianName,
    String? motherName,
    String? primaryPhone,
    String? secondaryPhone,
    String? address,
  });

  Future<FamilyDetails> getFamilyDetails(int id);

  /// The next available generated ID, e.g. `FAM-000002`.
  Future<String> nextFamilyId();
}
