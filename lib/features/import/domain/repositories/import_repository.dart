import '../entities/custom_field.dart';
import '../entities/dedup_record.dart';
import '../entities/export_student_row.dart';
import '../entities/import_plan.dart';
import '../entities/import_result.dart';

/// Data operations for the Excel import/export module.
///
/// Implementations enforce that custom field definitions are unique per
/// entity type, values are attached to real records, and the whole import is
/// applied in a single transaction (per-row constraint failures are recorded
/// and skipped; anything else rolls the transaction back).
abstract interface class ImportRepository {
  Future<List<CustomFieldDefinition>> listCustomFields({
    String? entityType,
    bool activeOnly = true,
  });

  /// Looks a definition up by field name or display name (normalized).
  Future<CustomFieldDefinition?> findCustomField(String entityType, String key);

  Future<CustomFieldDefinition> createCustomField({
    required String entityType,
    required String fieldName,
    required String displayName,
    required CustomFieldDataType dataType,
  });

  Future<void> saveCustomFieldValue({
    required int definitionId,
    required String entityType,
    required int entityId,
    String? value,
  });

  /// All values of the given active definitions, keyed by field name, for the
  /// given entities: `{ fieldName: { entityId: value } }`.
  Future<Map<String, Map<int, String?>>> allCustomFieldValuesFor({
    required String entityType,
    required List<int> entityIds,
  });

  Future<Set<String>> existingStudentIds();

  Future<Set<String>> existingAdmissionNumbers();

  Future<List<StudentDedupRecord>> studentsForDedup();

  Future<List<FamilyDedupRecord>> familiesForDedup();

  /// Resolves a `FAM-...` family ID to its numeric DB id, or null.
  Future<int?> findFamilyIdByFamilyId(String familyId);

  /// Applies [plan] inside one transaction. Rows whose insert fails a
  /// constraint are recorded in [ImportResult.failures] and skipped; any
  /// other error aborts and rolls back the whole transaction.
  Future<ImportResult> importPlan(
    ImportPlan plan, {
    bool includePossibleDuplicates = false,
    void Function(int processed, int total)? onProgress,
  });

  /// All students with their family and admission details, for export.
  Future<List<ExportStudentRow>> exportRows();
}
