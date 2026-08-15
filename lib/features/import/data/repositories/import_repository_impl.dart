import 'package:sqflite/sqflite.dart';

import '../../domain/entities/column_mapping.dart';
import '../../domain/entities/custom_field.dart';
import '../../domain/entities/dedup_record.dart';
import '../../domain/entities/export_student_row.dart';
import '../../domain/entities/import_family_group.dart';
import '../../domain/entities/import_fields.dart';
import '../../domain/entities/import_plan.dart';
import '../../domain/entities/import_result.dart';
import '../../domain/entities/import_row.dart';
import '../../domain/repositories/import_repository.dart';

/// SQL implementation of [ImportRepository] over `custom_field_definitions`,
/// `custom_field_values`, and (for the import itself) the `families`,
/// `students` and `admissions` tables.
///
/// The import runs in one transaction: a per-row constraint failure is
/// recorded and that row skipped, but any other error aborts and rolls back
/// the whole batch so nothing is half-applied.
class ImportRepositoryImpl implements ImportRepository {
  ImportRepositoryImpl(this._db);

  final Database _db;

  static const String _definitionPrefix = 'CFD-';
  static const String _studentPrefix = 'STU-';
  static const String _admissionPrefix = 'ADM-';
  static const String _familyPrefix = 'FAM-';
  static const int _idWidth = 6;

  @override
  Future<List<CustomFieldDefinition>> listCustomFields({
    String? entityType,
    bool activeOnly = true,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (entityType != null) {
      where.add('entity_type = ?');
      args.add(entityType);
    }
    if (activeOnly) {
      where.add('is_active = 1');
    }
    final rows = await _db.query(
      'custom_field_definitions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'entity_type, display_name',
    );
    return rows.map(_definitionFromRow).toList();
  }

  @override
  Future<CustomFieldDefinition?> findCustomField(
    String entityType,
    String key,
  ) async {
    final comparable = _comparable(key);
    final defs = await listCustomFields(entityType: entityType);
    for (final def in defs) {
      if (_comparable(def.fieldName) == comparable ||
          _comparable(def.displayName) == comparable) {
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
    final now = DateTime.now().toUtc().toIso8601String();
    final definitionId = await _nextId(
      _db,
      'custom_field_definitions',
      'definition_id',
      _definitionPrefix,
    );
    final id = await _db.insert('custom_field_definitions', {
      'definition_id': definitionId,
      'entity_type': entityType,
      'field_name': fieldName,
      'display_name': displayName,
      'data_type': dataType.dbValue,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    final rows = await _db.query(
      'custom_field_definitions',
      where: 'id = ?',
      whereArgs: [id],
    );
    return _definitionFromRow(rows.first);
  }

  @override
  Future<void> saveCustomFieldValue({
    required int definitionId,
    required String entityType,
    required int entityId,
    String? value,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = await _db.query(
      'custom_field_values',
      where: 'definition_id = ? AND entity_type = ? AND entity_id = ?',
      whereArgs: [definitionId, entityType, entityId],
    );
    if (existing.isEmpty) {
      await _db.insert('custom_field_values', {
        'definition_id': definitionId,
        'entity_type': entityType,
        'entity_id': entityId,
        'value': value,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await _db.update(
        'custom_field_values',
        {'value': value, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  @override
  Future<Map<String, Map<int, String?>>> allCustomFieldValuesFor({
    required String entityType,
    required List<int> entityIds,
  }) async {
    final result = <String, Map<int, String?>>{};
    if (entityIds.isEmpty) return result;
    final ids = entityIds.toSet().toList();
    final defs = await listCustomFields(entityType: entityType);
    if (defs.isEmpty) return result;
    final defIds = defs.map((d) => d.id).toList();
    final placeholders = List.filled(defIds.length, '?').join(', ');
    final rows = await _db.rawQuery(
      '''
      SELECT v.definition_id, v.entity_id, v.value, d.field_name
      FROM custom_field_values v
      JOIN custom_field_definitions d ON d.id = v.definition_id
      WHERE v.definition_id IN ($placeholders)
        AND v.entity_type = ?
        AND v.entity_id IN (${List.filled(ids.length, '?').join(', ')})
      ''',
      [...defIds, entityType, ...ids],
    );
    for (final row in rows) {
      final fieldName = row['field_name'] as String;
      final entityId = row['entity_id'] as int;
      result.putIfAbsent(fieldName, () => {})[entityId] =
          row['value'] as String?;
    }
    return result;
  }

  @override
  Future<Set<String>> existingStudentIds() async {
    final rows = await _db.query('students', columns: ['student_id']);
    return rows.map((r) => r['student_id'] as String).toSet();
  }

  @override
  Future<Set<String>> existingAdmissionNumbers() async {
    final rows = await _db.rawQuery(
      "SELECT admission_number FROM students "
      "WHERE admission_number IS NOT NULL AND admission_number <> ''",
    );
    return rows
        .map((r) => _comparable(r['admission_number'] as String))
        .toSet();
  }

  @override
  Future<List<StudentDedupRecord>> studentsForDedup() async {
    final rows = await _db.rawQuery('''
      SELECT s.id, s.student_id, s.name, s.family_id, s.admission_number,
             f.guardian_name, f.phone, f.alternate_phone
      FROM students s
      JOIN families f ON f.id = s.family_id
      ''');
    return rows.map((r) {
      return StudentDedupRecord(
        id: r['id'] as int,
        studentId: r['student_id'] as String,
        name: r['name'] as String,
        familyId: r['family_id'] as int,
        admissionNumber: r['admission_number'] as String?,
        guardianName: r['guardian_name'] as String?,
        primaryPhone: r['phone'] as String?,
        secondaryPhone: r['alternate_phone'] as String?,
      );
    }).toList();
  }

  @override
  Future<List<FamilyDedupRecord>> familiesForDedup() async {
    final rows = await _db.query('families');
    return rows.map((r) {
      return FamilyDedupRecord(
        id: r['id'] as int,
        familyId: r['family_id'] as String,
        guardianName: r['guardian_name'] as String,
        motherName: r['mother_name'] as String?,
        primaryPhone: r['phone'] as String?,
        secondaryPhone: r['alternate_phone'] as String?,
        cnic: r['cnic'] as String?,
        address: r['address'] as String?,
      );
    }).toList();
  }

  @override
  Future<int?> findFamilyIdByFamilyId(String familyId) async {
    final rows = await _db.rawQuery(
      'SELECT id FROM families WHERE LOWER(TRIM(family_id)) = LOWER(TRIM(?))',
      [familyId],
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  @override
  Future<ImportResult> importPlan(
    ImportPlan plan, {
    bool includePossibleDuplicates = false,
    void Function(int processed, int total)? onProgress,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    // Rows selected for import, in file order.
    final selected = plan.rows.where((r) {
      return r.verdict == ImportRowVerdict.valid ||
          (r.verdict == ImportRowVerdict.possibleDuplicate &&
              includePossibleDuplicates);
    }).toList();
    final skippedDuplicates =
        plan.duplicateCount +
        plan.rows
            .where(
              (r) =>
                  r.verdict == ImportRowVerdict.possibleDuplicate &&
                  !includePossibleDuplicates,
            )
            .length;
    final skippedInvalid = plan.invalidCount;

    var importedFamilies = 0;
    var importedStudents = 0;
    final createdCustomFields = <String>[];
    final failures = <ImportRowError>[];

    final customColumns = plan.columns
        .where((c) => c.kind == ColumnTargetKind.custom)
        .toList();
    final processed = <int, bool>{}; // row index -> included

    await _db.transaction((txn) async {
      // 1. Ensure every custom field definition exists (idempotent by name).
      final definitionIds = <String, int>{};
      for (final column in customColumns) {
        final fieldName = column.customFieldName!;
        final key = '${column.customEntityType}:$fieldName';
        final existing = await _findCustomFieldTxn(
          txn,
          column.customEntityType!,
          column.customDisplayName ?? fieldName,
        );
        int definitionId;
        if (existing != null) {
          definitionId = existing.id;
        } else {
          final created = await _insertDefinition(
            txn,
            entityType: column.customEntityType!,
            fieldName: fieldName,
            displayName: column.customDisplayName ?? fieldName,
            dataType: column.customDataType ?? CustomFieldDataType.text,
            now: now,
          );
          definitionId = created;
          createdCustomFields.add(column.customDisplayName ?? fieldName);
        }
        definitionIds[key] = definitionId;
      }

      // 2. Import family groups (in order of first occurrence).
      final groupIndexByRow = <int, int>{};
      for (var gi = 0; gi < plan.familyGroups.length; gi++) {
        for (final rowIndex in plan.familyGroups[gi].rowIndices) {
          groupIndexByRow[rowIndex] = gi;
        }
      }

      final groupedSelected = <int, List<ImportRow>>{};
      for (final row in selected) {
        final gi = groupIndexByRow[row.index];
        if (gi == null) continue;
        groupedSelected.putIfAbsent(gi, () => []).add(row);
      }

      for (final entry in groupedSelected.entries) {
        final group = plan.familyGroups[entry.key];
        final groupRows = entry.value;
        processed[groupRows.first.index] = true;
        int? familyRowId;
        try {
          if (group.match == ImportFamilyMatch.existing) {
            familyRowId = group.matchedFamilyDbId;
          } else {
            final familyId = await _nextId(
              txn,
              'families',
              'family_id',
              _familyPrefix,
            );
            familyRowId = await txn.insert('families', {
              'family_id': familyId,
              'guardian_name': group.guardianName,
              'mother_name': _emptyToNull(group.motherName),
              'phone': _emptyToNull(group.primaryPhone),
              'alternate_phone': _emptyToNull(group.secondaryPhone),
              'address': _emptyToNull(group.address),
              'cnic': _emptyToNull(group.cnic),
              'notes': null,
              'status': 'active',
              'created_at': now,
              'updated_at': now,
            });
            importedFamilies += 1;
          }
        } on DatabaseException catch (e) {
          if (_isConstraintError(e)) {
            failures.add(
              ImportRowError(
                'Family',
                'Could not create family for "${group.guardianName}": $e',
              ),
            );
            continue;
          }
          rethrow;
        }

        // Family custom field values (from the first row of the group).
        for (final column in customColumns) {
          if (column.customEntityType != 'family') continue;
          final firstRow = groupRows.first;
          final key = 'family:${column.customFieldName}';
          final definitionId = definitionIds[key];
          if (definitionId == null) continue;
          final value = _stringify(
            firstRow.customValues[column.customFieldName],
          );
          await _saveValue(
            txn,
            definitionId: definitionId,
            entityType: 'family',
            entityId: familyRowId!,
            value: value,
            now: now,
          );
        }

        // Student rows of this group.
        for (final row in groupRows) {
          processed[row.index] = true;
          try {
            final studentRowId = await _insertStudentRow(
              txn,
              row: row,
              familyRowId: familyRowId!,
              now: now,
            );
            importedStudents += 1;

            for (final column in customColumns) {
              if (column.customEntityType != 'student') continue;
              final key = 'student:${column.customFieldName}';
              final definitionId = definitionIds[key];
              if (definitionId == null) continue;
              await _saveValue(
                txn,
                definitionId: definitionId,
                entityType: 'student',
                entityId: studentRowId,
                value: _stringify(row.customValues[column.customFieldName]),
                now: now,
              );
            }
          } on DatabaseException catch (e) {
            if (_isConstraintError(e)) {
              failures.add(
                ImportRowError(
                  'Row ${row.index + 2}',
                  '${row.studentName ?? 'Student'} — $e',
                ),
              );
              continue;
            }
            rethrow;
          }
          onProgress?.call(processed.length, selected.length);
        }
      }

      // Rows that were selected but never grouped (defensive).
      for (final row in selected) {
        if (processed[row.index] == true) continue;
        processed[row.index] = true;
        failures.add(
          ImportRowError(
            'Row ${row.index + 2}',
            '${row.studentName ?? 'Student'} could not be assigned to a family.',
          ),
        );
        onProgress?.call(processed.length, selected.length);
      }
    });

    return ImportResult(
      importedFamilies: importedFamilies,
      importedStudents: importedStudents,
      skippedDuplicates: skippedDuplicates,
      skippedInvalid: skippedInvalid,
      createdCustomFields: createdCustomFields,
      failures: failures,
    );
  }

  Future<int> _insertStudentRow(
    DatabaseExecutor txn, {
    required ImportRow row,
    required int familyRowId,
    required String now,
  }) async {
    final studentId = await _nextId(
      txn,
      'students',
      'student_id',
      _studentPrefix,
    );
    final admissionId = await _nextId(
      txn,
      'admissions',
      'admission_id',
      _admissionPrefix,
    );
    final name = (row.coreValues[ImportCoreField.studentName] as String?)!
        .trim();
    final admissionNumber = _emptyToNull(
      row.coreValues[ImportCoreField.admissionNumber] as String?,
    );
    final admissionDate =
        (row.coreValues[ImportCoreField.admissionDate] as DateTime?) ??
        DateTime.now();
    final gender = row.coreValues[ImportCoreField.gender] as String?;
    final studentRowId = await txn.insert('students', {
      'student_id': studentId,
      'family_id': familyRowId,
      'name': name,
      'gender': gender,
      'date_of_birth': _dateToIso(
        row.coreValues[ImportCoreField.dateOfBirth] as DateTime?,
      ),
      'class': _emptyToNull(
        row.coreValues[ImportCoreField.className] as String?,
      ),
      'section': _emptyToNull(
        row.coreValues[ImportCoreField.section] as String?,
      ),
      'admission_number': admissionNumber,
      'admission_date': _dateToIso(admissionDate),
      'contact_reference': _emptyToNull(
        row.coreValues[ImportCoreField.contactReference] as String?,
      ),
      'notes': _emptyToNull(row.coreValues[ImportCoreField.notes] as String?),
      'status': 'active',
      'created_at': now,
      'updated_at': now,
    });
    await txn.insert('admissions', {
      'admission_id': admissionId,
      'student_id': studentRowId,
      'admission_number': admissionNumber,
      'admission_date': _dateToIso(admissionDate),
      'class': _emptyToNull(
        row.coreValues[ImportCoreField.className] as String?,
      ),
      'section': _emptyToNull(
        row.coreValues[ImportCoreField.section] as String?,
      ),
      'admission_fee':
          (row.coreValues[ImportCoreField.admissionFee] as num?)?.toDouble() ??
          0,
      'notes': _emptyToNull(row.coreValues[ImportCoreField.notes] as String?),
      'created_at': now,
    });
    return studentRowId;
  }

  Future<int> _insertDefinition(
    DatabaseExecutor txn, {
    required String entityType,
    required String fieldName,
    required String displayName,
    required CustomFieldDataType dataType,
    required String now,
  }) async {
    final definitionId = await _nextId(
      txn,
      'custom_field_definitions',
      'definition_id',
      _definitionPrefix,
    );
    return txn.insert('custom_field_definitions', {
      'definition_id': definitionId,
      'entity_type': entityType,
      'field_name': fieldName,
      'display_name': displayName,
      'data_type': dataType.dbValue,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> _saveValue(
    DatabaseExecutor txn, {
    required int definitionId,
    required String entityType,
    required int entityId,
    required String? value,
    required String now,
  }) async {
    await txn.insert('custom_field_values', {
      'definition_id': definitionId,
      'entity_type': entityType,
      'entity_id': entityId,
      'value': value,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<ExportStudentRow>> exportRows() async {
    final rows = await _db.rawQuery('''
      SELECT s.id, s.student_id, s.name, s.gender, s.date_of_birth,
             s.admission_number, s.admission_date, s.class, s.section,
             s.contact_reference, s.notes, s.status, s.family_id,
             f.family_id AS family_id_text,
             f.guardian_name, f.mother_name, f.phone, f.alternate_phone,
             f.address, f.cnic,
             COALESCE(a.admission_fee, 0) AS admission_fee
      FROM students s
      JOIN families f ON f.id = s.family_id
      LEFT JOIN admissions a ON a.id = (
        SELECT id FROM admissions
        WHERE student_id = s.id
        ORDER BY admission_date DESC, id DESC
        LIMIT 1
      )
      ORDER BY s.student_id
      ''');
    return rows.map((r) {
      return ExportStudentRow(
        id: r['id'] as int,
        studentId: r['student_id'] as String,
        name: r['name'] as String,
        familyId: r['family_id'] as int,
        familyIdText: r['family_id_text'] as String?,
        gender: r['gender'] as String?,
        dateOfBirth: _parseDateOrNull(r['date_of_birth']),
        admissionNumber: r['admission_number'] as String?,
        admissionDate: _parseDateOrNull(r['admission_date']),
        className: r['class'] as String?,
        section: r['section'] as String?,
        admissionFee: (r['admission_fee'] as num?)?.toDouble() ?? 0,
        contactReference: r['contact_reference'] as String?,
        notes: r['notes'] as String?,
        status: r['status'] as String?,
        guardianName: r['guardian_name'] as String?,
        motherName: r['mother_name'] as String?,
        primaryPhone: r['phone'] as String?,
        secondaryPhone: r['alternate_phone'] as String?,
        address: r['address'] as String?,
        cnic: r['cnic'] as String?,
      );
    }).toList();
  }

  Future<CustomFieldDefinition?> _findCustomFieldTxn(
    DatabaseExecutor txn,
    String entityType,
    String key,
  ) async {
    final comparable = _comparable(key);
    final rows = await txn.query(
      'custom_field_definitions',
      where: 'entity_type = ?',
      whereArgs: [entityType],
    );
    for (final row in rows) {
      final def = _definitionFromRow(row);
      if (_comparable(def.fieldName) == comparable ||
          _comparable(def.displayName) == comparable) {
        return def;
      }
    }
    return null;
  }

  static Future<String> _nextId(
    DatabaseExecutor executor,
    String table,
    String column,
    String prefix,
  ) async {
    final row = await executor.rawQuery(
      'SELECT COALESCE(MAX(CAST(SUBSTR($column, ?) AS INTEGER)), 0) AS m '
      'FROM $table',
      [prefix.length + 1],
    );
    final maxValue = _asInt(row.first['m']);
    return '$prefix${(maxValue + 1).toString().padLeft(_idWidth, '0')}';
  }

  static CustomFieldDefinition _definitionFromRow(Map<String, Object?> row) {
    return CustomFieldDefinition(
      id: _asInt(row['id']),
      definitionId: row['definition_id'] as String,
      entityType: row['entity_type'] as String,
      fieldName: row['field_name'] as String,
      displayName: row['display_name'] as String,
      dataType: CustomFieldDataType.fromDb(row['data_type'] as String),
      isActive: (row['is_active'] as int?) != 0,
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  static String? _emptyToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _dateToIso(DateTime? value) => value?.toIso8601String();

  static String? _stringify(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is bool) return value ? '1' : '0';
    return value.toString();
  }

  /// True when the failure is a row-level SQLite constraint violation that
  /// should skip that row instead of aborting the import transaction.
  static bool _isConstraintError(DatabaseException e) {
    if (e.isUniqueConstraintError() || e.isNotNullConstraintError()) {
      return true;
    }
    final code = e.getResultCode();
    if (code == null) return false;
    // SQLITE_CONSTRAINT = 19. Extended codes keep the primary code in the low
    // byte (e.g. 0x0313 = SQLITE_CONSTRAINT_FOREIGNKEY), so mask it off.
    return code == 19 || (code & 0xFF) == 19;
  }

  static String _comparable(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static DateTime _parseDate(Object? value) =>
      DateTime.tryParse(value as String)?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  static DateTime? _parseDateOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String)?.toLocal();
  }

  static int _asInt(Object? value) => (value as num?)?.toInt() ?? 0;
}
