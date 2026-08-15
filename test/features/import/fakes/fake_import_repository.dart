import 'package:school_office_management/features/import/application/import_service.dart';
import 'package:school_office_management/features/import/domain/entities/custom_field.dart';
import 'package:school_office_management/features/import/domain/entities/dedup_record.dart';
import 'package:school_office_management/features/import/domain/entities/export_student_row.dart';
import 'package:school_office_management/features/import/domain/entities/import_plan.dart';
import 'package:school_office_management/features/import/domain/entities/import_result.dart';
import 'package:school_office_management/features/import/domain/repositories/import_repository.dart';
import 'package:school_office_management/features/import/domain/services/column_mapper.dart';
import 'package:school_office_management/features/import/domain/services/excel_reader.dart';
import 'package:school_office_management/features/import/domain/services/export_service.dart';
import 'package:school_office_management/features/import/domain/services/import_planner.dart';

/// In-memory [ImportRepository] for tests. Keeps whatever the import would
/// have written so tests can assert on it, without touching a database.
class FakeImportRepository implements ImportRepository {
  final List<CustomFieldDefinition> definitions = [];
  final Map<int, Map<int, String?>> values = {};
  final Set<String> studentIds = {};
  final Set<String> admissionNumbers = {};
  final List<StudentDedupRecord> dbStudents = [];
  final List<FamilyDedupRecord> dbFamilies = [];
  final Map<String, int> familyIdsByText = {};

  ImportPlan? lastPlan;
  bool lastIncludePossibleDuplicates = false;
  List<ExportStudentRow> exportRowsResult = const [];
  ImportResult result = ImportResult(
    importedFamilies: 0,
    importedStudents: 0,
    skippedDuplicates: 0,
    skippedInvalid: 0,
    createdCustomFields: const [],
    failures: const [],
  );

  int _nextId = 1;

  @override
  Future<List<CustomFieldDefinition>> listCustomFields({
    String? entityType,
    bool activeOnly = true,
  }) async {
    return definitions.where((d) {
      if (entityType != null && d.entityType != entityType) return false;
      if (activeOnly && !d.isActive) return false;
      return true;
    }).toList();
  }

  @override
  Future<CustomFieldDefinition?> findCustomField(
    String entityType,
    String key,
  ) async {
    final comparable = key.trim().toLowerCase().replaceAll('_', ' ');
    for (final def in definitions) {
      final field = def.fieldName.trim().toLowerCase().replaceAll('_', ' ');
      final display = def.displayName.trim().toLowerCase();
      if (def.entityType == entityType &&
          (field == comparable || display == comparable)) {
        return def;
      }
    }
    return null;
  }

  @override
  Future<CustomFieldDefinition> createCustomField({
    required String entityType,
    required String fieldName,
    required String displayName,
    required CustomFieldDataType dataType,
  }) async {
    final def = CustomFieldDefinition(
      id: _nextId++,
      definitionId: 'CFD-${(_nextId).toString().padLeft(6, '0')}',
      entityType: entityType,
      fieldName: fieldName,
      displayName: displayName,
      dataType: dataType,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    definitions.add(def);
    return def;
  }

  @override
  Future<void> saveCustomFieldValue({
    required int definitionId,
    required String entityType,
    required int entityId,
    String? value,
  }) async {
    values.putIfAbsent(definitionId, () => {})[entityId] = value;
  }

  @override
  Future<Map<String, Map<int, String?>>> allCustomFieldValuesFor({
    required String entityType,
    required List<int> entityIds,
  }) async {
    final result = <String, Map<int, String?>>{};
    for (final def in definitions.where((d) => d.entityType == entityType)) {
      final byEntity = values[def.id] ?? {};
      result[def.fieldName] = {
        for (final id in entityIds)
          if (byEntity[id] != null) id: byEntity[id],
      };
    }
    return result;
  }

  @override
  Future<Set<String>> existingStudentIds() async => studentIds;

  @override
  Future<Set<String>> existingAdmissionNumbers() async => admissionNumbers;

  @override
  Future<List<StudentDedupRecord>> studentsForDedup() async => dbStudents;

  @override
  Future<List<FamilyDedupRecord>> familiesForDedup() async => dbFamilies;

  @override
  Future<int?> findFamilyIdByFamilyId(String familyId) async {
    return familyIdsByText[familyId.trim().toLowerCase()];
  }

  @override
  Future<ImportResult> importPlan(
    ImportPlan plan, {
    bool includePossibleDuplicates = false,
    void Function(int processed, int total)? onProgress,
  }) async {
    lastPlan = plan;
    lastIncludePossibleDuplicates = includePossibleDuplicates;
    return result;
  }

  @override
  Future<List<ExportStudentRow>> exportRows() async => exportRowsResult;
}

/// A ready-to-use [ImportService] wired to fakes, for widget tests that just
/// need the dashboard/import screens to build.
ImportService buildTestImportService({FakeImportRepository? repository}) {
  final repo = repository ?? FakeImportRepository();
  return ImportService(
    reader: ExcelReader(),
    mapper: ColumnMapper(),
    planner: ImportPlanner(),
    repository: repo,
    exportService: ExportService(repo),
  );
}
