import '../entities/column_mapping.dart';
import '../entities/dedup_record.dart';
import '../entities/import_family_group.dart';
import '../entities/import_fields.dart';
import '../entities/import_plan.dart';
import '../entities/import_row.dart';
import '../repositories/import_repository.dart';
import 'row_validator.dart';

/// Builds an [ImportPlan]: parses/validates every row, groups rows into
/// families, and classifies duplicates. Everything is read-only — nothing is
/// written here.
class ImportPlanner {
  ImportPlanner({RowValidator? validator})
    : _validator = validator ?? RowValidator();

  final RowValidator _validator;

  Future<ImportPlan> buildPlan({
    required String sheetName,
    required List<ColumnMapping> columns,
    required List<List<Object?>> sheetRows,
    required ImportRepository repository,
  }) async {
    final existingStudentIds = await repository.existingStudentIds();
    final existingAdmissionNumbers = await repository
        .existingAdmissionNumbers();
    final dbStudents = await repository.studentsForDedup();
    final dbFamilies = await repository.familiesForDedup();

    // Resolve any "existing family ID" columns up front.
    final resolvedFamilyIds = <String, int?>{};
    for (final column in columns) {
      if (!column.isCore ||
          column.coreField != ImportCoreField.existingFamilyId) {
        continue;
      }
      for (final row in sheetRows) {
        final raw = column.index < row.length ? row[column.index] : null;
        final value = raw?.toString().trim() ?? '';
        if (value.isEmpty ||
            resolvedFamilyIds.containsKey(value.toLowerCase())) {
          continue;
        }
        resolvedFamilyIds[value.toLowerCase()] = await repository
            .findFamilyIdByFamilyId(value);
      }
    }

    return plan(
      sheetName: sheetName,
      columns: columns,
      sheetRows: sheetRows,
      existingStudentIds: existingStudentIds,
      existingAdmissionNumbers: existingAdmissionNumbers,
      resolvedFamilyIds: resolvedFamilyIds,
      dbStudents: dbStudents,
      dbFamilies: dbFamilies,
    );
  }

  /// Pure planning logic (fully synchronous) so it is easy to unit test.
  ImportPlan plan({
    required String sheetName,
    required List<ColumnMapping> columns,
    required List<List<Object?>> sheetRows,
    required Set<String> existingStudentIds,
    required Set<String> existingAdmissionNumbers,
    required Map<String, int?> resolvedFamilyIds,
    required List<StudentDedupRecord> dbStudents,
    required List<FamilyDedupRecord> dbFamilies,
  }) {
    final rows = <ImportRow>[
      for (var i = 0; i < sheetRows.length; i++)
        ImportRow(index: i, rawValues: sheetRows[i]),
    ];

    // Infer data types for brand-new custom field columns.
    for (final column in columns) {
      if (column.isCustom && column.customDataType == null) {
        column.customDataType = _validator.inferCustomType(
          sheetRows,
          column.index,
        );
      }
    }

    for (final row in rows) {
      _validator.validateRow(row, columns);
    }

    final groups = _buildFamilyGroups(
      rows: rows,
      columns: columns,
      resolvedFamilyIds: resolvedFamilyIds,
      dbFamilies: dbFamilies,
    );

    _classify(
      rows: rows,
      groups: groups,
      existingStudentIds: existingStudentIds.map(_norm).toSet(),
      existingAdmissionNumbers: existingAdmissionNumbers.map(_norm).toSet(),
      dbStudents: dbStudents,
    );

    return ImportPlan(
      sheetName: sheetName,
      columns: columns,
      rows: rows,
      familyGroups: groups,
    );
  }

  List<ImportFamilyGroup> _buildFamilyGroups({
    required List<ImportRow> rows,
    required List<ColumnMapping> columns,
    required Map<String, int?> resolvedFamilyIds,
    required List<FamilyDedupRecord> dbFamilies,
  }) {
    final groups = <ImportFamilyGroup>[];
    final indexByKey = <String, int>{};

    // Rows referencing an existing family resolve to that family; every other
    // row resolves to a (new) group keyed by its strongest signal.
    for (final row in rows) {
      final existingFamilyId = row.existingFamilyIdValue;
      String? key;
      if (existingFamilyId != null && existingFamilyId.isNotEmpty) {
        final lookupKey = existingFamilyId.trim().toLowerCase();
        final dbId = resolvedFamilyIds[lookupKey];
        if (dbId == null) {
          row.errors.add(
            ImportRowError(
              'Existing Family ID',
              '"$existingFamilyId" was not found in the database.',
            ),
          );
          continue;
        }
        key = 'existing:$dbId';
        var index = indexByKey[key];
        if (index == null) {
          index = groups.length;
          final group = ImportFamilyGroup(
            guardianName: row.guardianNameForFamily ?? row.studentName ?? '',
          );
          group.match = ImportFamilyMatch.existing;
          group.matchedFamilyDbId = dbId;
          groups.add(group);
          indexByKey[key] = index;
        }
        final group = groups[index];
        group.rowIndices.add(row.index);
        row.familyGroupIndex = index;
        continue;
      }

      key = ImportFamilyGroup.groupKeyFor(
        guardianName: row.guardianNameForFamily ?? row.studentName ?? '',
        cnic: _rowValue(row, ImportCoreField.cnic) as String?,
        primaryPhone: _rowValue(row, ImportCoreField.primaryPhone) as String?,
      );
      var index = indexByKey[key];
      if (index == null) {
        index = groups.length;
        final group = ImportFamilyGroup(
          guardianName: row.guardianNameForFamily ?? row.studentName ?? '',
        );
        group.motherName =
            _rowValue(row, ImportCoreField.motherName) as String?;
        group.primaryPhone =
            _rowValue(row, ImportCoreField.primaryPhone) as String?;
        group.secondaryPhone =
            _rowValue(row, ImportCoreField.secondaryPhone) as String?;
        group.address = _rowValue(row, ImportCoreField.address) as String?;
        group.cnic = _rowValue(row, ImportCoreField.cnic) as String?;
        groups.add(group);
        indexByKey[key] = index;
      }
      final group = groups[index];
      group.rowIndices.add(row.index);
      row.familyGroupIndex = index;
    }

    // Family custom field values come from the first row of the group.
    for (final column in columns) {
      if (!column.isCustom || column.customEntityType != 'family') continue;
      for (final group in groups) {
        if (group.rowIndices.isEmpty) continue;
        final first = rows.firstWhere((r) => r.index == group.rowIndices.first);
        final value = first.customValues[column.customFieldName];
        if (value != null) {
          group.customValues[column.customFieldName!] = value;
        }
      }
    }

    // Possible family duplicates: strong-signal match only (never name alone).
    for (final group in groups) {
      if (group.match != ImportFamilyMatch.none) continue;
      final match = _possibleFamilyMatch(group, dbFamilies);
      if (match != null) {
        group.match = ImportFamilyMatch.possibleDuplicate;
        group.matchMessage =
            'Looks like family ${match.familyId} (${match.guardianName}).';
      }
    }

    return groups;
  }

  FamilyDedupRecord? _possibleFamilyMatch(
    ImportFamilyGroup group,
    List<FamilyDedupRecord> dbFamilies,
  ) {
    final phoneDigits = _onlyDigits(group.primaryPhone ?? '');
    final cnicDigits = _onlyDigits(group.cnic ?? '');
    final address = _norm(group.address ?? '');
    for (final candidate in dbFamilies) {
      if (cnicDigits.isNotEmpty &&
          _onlyDigits(candidate.cnic ?? '').isNotEmpty &&
          cnicDigits == _onlyDigits(candidate.cnic ?? '')) {
        return candidate;
      }
      if (phoneDigits.isNotEmpty &&
          _onlyDigits(candidate.primaryPhone ?? '').isNotEmpty &&
          phoneDigits == _onlyDigits(candidate.primaryPhone ?? '')) {
        return candidate;
      }
      if (address.isNotEmpty &&
          _norm(candidate.address ?? '').isNotEmpty &&
          address == _norm(candidate.address ?? '')) {
        return candidate;
      }
    }
    return null;
  }

  void _classify({
    required List<ImportRow> rows,
    required List<ImportFamilyGroup> groups,
    required Set<String> existingStudentIds,
    required Set<String> existingAdmissionNumbers,
    required List<StudentDedupRecord> dbStudents,
  }) {
    final seenAdmissionsInFile = <String>{};
    final seenStudentIdsInFile = <String>{};
    final seenNamesInGroup = <int, Set<String>>{};

    for (final row in rows) {
      if (row.errors.isNotEmpty) {
        row.verdict = ImportRowVerdict.invalid;
        row.verdictMessage = 'Missing or invalid data — skipped.';
        continue;
      }

      var verdict = ImportRowVerdict.valid;
      String? message;

      final admission = _norm(row.admissionNumber ?? '');
      if (admission.isNotEmpty) {
        if (existingAdmissionNumbers.contains(admission)) {
          verdict = ImportRowVerdict.duplicate;
          message = 'Admission number "${row.admissionNumber}" already exists.';
        } else if (seenAdmissionsInFile.contains(admission)) {
          verdict = ImportRowVerdict.duplicate;
          message =
              'Admission number "${row.admissionNumber}" appears more than once in the file.';
        } else {
          seenAdmissionsInFile.add(admission);
        }
      }

      final studentId = _norm(row.studentIdValue ?? '');
      if (verdict == ImportRowVerdict.valid && studentId.isNotEmpty) {
        if (existingStudentIds.contains(studentId)) {
          verdict = ImportRowVerdict.duplicate;
          message = 'Student ID "${row.studentIdValue}" already exists.';
        } else if (seenStudentIdsInFile.contains(studentId)) {
          verdict = ImportRowVerdict.duplicate;
          message =
              'Student ID "${row.studentIdValue}" appears more than once in the file.';
        } else {
          seenStudentIdsInFile.add(studentId);
        }
      }

      if (verdict == ImportRowVerdict.valid) {
        final dbPossible = _possibleStudentMatch(row, dbStudents);
        if (dbPossible != null) {
          verdict = ImportRowVerdict.possibleDuplicate;
          message =
              'Similar to ${dbPossible.name} (${dbPossible.studentId}). Review before importing.';
        }
      }

      if (verdict == ImportRowVerdict.valid) {
        final groupIndex = row.familyGroupIndex;
        final name = _norm(row.studentName ?? '');
        if (name.isNotEmpty && groupIndex != null) {
          final names = seenNamesInGroup.putIfAbsent(
            groupIndex,
            () => <String>{},
          );
          if (names.contains(name)) {
            verdict = ImportRowVerdict.possibleDuplicate;
            message =
                'A student with this name already appears in the same family group.';
          } else {
            names.add(name);
          }
        }
      }

      if (verdict == ImportRowVerdict.valid && row.familyGroupIndex != null) {
        final group = groups[row.familyGroupIndex!];
        if (group.match == ImportFamilyMatch.possibleDuplicate) {
          verdict = ImportRowVerdict.possibleDuplicate;
          message = group.matchMessage;
        }
      }

      row.verdict = verdict;
      row.verdictMessage = message;
    }
  }

  StudentDedupRecord? _possibleStudentMatch(
    ImportRow row,
    List<StudentDedupRecord> dbStudents,
  ) {
    final name = _norm(row.studentName ?? '');
    if (name.isEmpty) return null;
    final groupIndex = row.familyGroupIndex;
    final phoneDigits = groupIndex == null
        ? ''
        : _onlyDigits(
            _rowValue(row, ImportCoreField.primaryPhone) as String? ?? '',
          );
    final guardian = _norm(
      _rowValue(row, ImportCoreField.guardianName) as String? ?? '',
    );
    for (final candidate in dbStudents) {
      if (_norm(candidate.name) != name) continue;
      if (phoneDigits.isNotEmpty &&
          _onlyDigits(candidate.primaryPhone ?? '').isNotEmpty &&
          phoneDigits == _onlyDigits(candidate.primaryPhone ?? '')) {
        return candidate;
      }
      if (guardian.isNotEmpty &&
          _norm(candidate.guardianName ?? '') == guardian) {
        return candidate;
      }
    }
    return null;
  }

  static Object? _rowValue(ImportRow row, ImportCoreField field) {
    return row.coreValues[field];
  }

  static String _norm(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _onlyDigits(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');
}
