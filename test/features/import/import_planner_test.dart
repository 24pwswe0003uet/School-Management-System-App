import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/import/domain/entities/column_mapping.dart';
import 'package:school_office_management/features/import/domain/entities/dedup_record.dart';
import 'package:school_office_management/features/import/domain/entities/import_family_group.dart';
import 'package:school_office_management/features/import/domain/entities/import_fields.dart';
import 'package:school_office_management/features/import/domain/entities/import_plan.dart';
import 'package:school_office_management/features/import/domain/entities/import_row.dart';
import 'package:school_office_management/features/import/domain/services/import_planner.dart';

void main() {
  final planner = ImportPlanner();

  List<ColumnMapping> columns(
    Map<ImportCoreField, int> indexByField,
    int width,
  ) {
    final byIndex = <int, ColumnMapping>{};
    indexByField.forEach((field, index) {
      byIndex[index] = ColumnMapping(
        index: index,
        sourceHeader: field.displayName,
        normalizedHeader: field.displayName,
        kind: ColumnTargetKind.core,
        status: ColumnMatchStatus.autoMatched,
        coreField: field,
      );
    });
    return [
      for (var i = 0; i < width; i++)
        byIndex[i] ??
            ColumnMapping(
              index: i,
              sourceHeader: '',
              normalizedHeader: '',
              kind: ColumnTargetKind.ignored,
              status: ColumnMatchStatus.ignored,
            ),
    ];
  }

  const indexes = {
    ImportCoreField.studentName: 0,
    ImportCoreField.guardianName: 1,
    ImportCoreField.primaryPhone: 2,
    ImportCoreField.admissionNumber: 3,
    ImportCoreField.cnic: 4,
  };
  final cols = columns(indexes, 5);

  List<List<Object?>> rows(List<List<Object?>> data) => data;

  ImportPlan build(
    List<List<Object?>> data, {
    Set<String> existingStudentIds = const {},
    Set<String> existingAdmissionNumbers = const {},
    List<StudentDedupRecord> dbStudents = const [],
    List<FamilyDedupRecord> dbFamilies = const [],
    Map<String, int?> resolvedFamilyIds = const {},
  }) {
    return planner.plan(
      sheetName: 'Students',
      columns: cols,
      sheetRows: rows(data),
      existingStudentIds: existingStudentIds,
      existingAdmissionNumbers: existingAdmissionNumbers,
      resolvedFamilyIds: resolvedFamilyIds,
      dbStudents: dbStudents,
      dbFamilies: dbFamilies,
    );
  }

  group('ImportPlanner.plan', () {
    test('valid rows are grouped and importable', () {
      final plan = build([
        [
          'Ali Khan',
          'Imran Khan',
          '0300-1111111',
          'ADM-001',
          '35202-1234567-1',
        ],
        [
          'Ayesha Khan',
          'Imran Khan',
          '0300-1111111',
          'ADM-002',
          '35202-1234567-1',
        ],
      ]);
      expect(plan.validCount, 2);
      expect(plan.invalidCount, 0);
      expect(plan.familiesNeeded, 1);
      // Siblings sharing guardian + CNIC are one family group.
      expect(plan.familyGroups, hasLength(1));
    });

    test('missing names are invalid', () {
      final plan = build([
        [null, 'Imran Khan', '0300-1111111', 'ADM-001', null],
      ]);
      expect(plan.invalidCount, 1);
      expect(plan.validCount, 0);
    });

    test('admission numbers already in the database are duplicates', () {
      final plan = build(
        [
          ['Ali Khan', 'Imran Khan', '0300-1111111', 'ADM-100', null],
        ],
        existingAdmissionNumbers: {'adm-100'},
      );
      expect(plan.duplicateCount, 1);
      expect(plan.validCount, 0);
      expect(plan.rows.first.verdict, ImportRowVerdict.duplicate);
    });

    test('admission numbers repeated within the file are duplicates', () {
      final plan = build([
        ['Ali Khan', 'Imran Khan', '0300-1111111', 'ADM-100', null],
        ['Sana', 'Umar', '0301-2222222', 'ADM-100', null],
      ]);
      expect(plan.duplicateCount, 1);
      expect(plan.validCount, 1);
    });

    test('existing student IDs are duplicates', () {
      final withStudentId = columns({
        ImportCoreField.studentName: 0,
        ImportCoreField.studentId: 1,
      }, 2);
      final plan = planner.plan(
        sheetName: 'Students',
        columns: withStudentId,
        sheetRows: [
          ['Ali Khan', 'STU-000123'],
        ],
        existingStudentIds: {'stu-000123'},
        existingAdmissionNumbers: const {},
        resolvedFamilyIds: const {},
        dbStudents: const [],
        dbFamilies: const [],
      );
      expect(plan.rows.first.verdict, ImportRowVerdict.duplicate);
    });

    test('same name + phone as a DB student is a possible duplicate', () {
      final plan = build(
        [
          ['Ali Khan', 'Imran Khan', '0300-1111111', null, null],
        ],
        dbStudents: [
          StudentDedupRecord(
            id: 1,
            studentId: 'STU-000001',
            name: 'Ali Khan',
            familyId: 1,
            admissionNumber: null,
            guardianName: 'Someone Else',
            primaryPhone: '0300-1111111',
            secondaryPhone: null,
          ),
        ],
      );
      expect(plan.rows.first.verdict, ImportRowVerdict.possibleDuplicate);
    });

    test('family matching by phone flags possible duplicate families', () {
      final plan = build(
        [
          ['Ali Khan', 'Imran Khan', '0300-1111111', null, null],
        ],
        dbFamilies: [
          FamilyDedupRecord(
            id: 1,
            familyId: 'FAM-000001',
            guardianName: 'Imran Khan',
            motherName: null,
            primaryPhone: '0300-1111111',
            secondaryPhone: null,
            cnic: null,
            address: null,
          ),
        ],
      );
      expect(
        plan.familyGroups.first.match,
        ImportFamilyMatch.possibleDuplicate,
      );
      expect(plan.rows.first.verdict, ImportRowVerdict.possibleDuplicate);
    });

    test('existing family IDs resolve to that family', () {
      final withFamilyIdCol = columns({
        ImportCoreField.studentName: 0,
        ImportCoreField.existingFamilyId: 1,
      }, 2);
      final plan = planner.plan(
        sheetName: 'Students',
        columns: withFamilyIdCol,
        sheetRows: [
          ['Ali Khan', 'FAM-000001'],
          ['Sana', 'FAM-000001'],
        ],
        existingStudentIds: const {},
        existingAdmissionNumbers: const {},
        resolvedFamilyIds: {'fam-000001': 42},
        dbStudents: const [],
        dbFamilies: const [],
      );
      expect(plan.validCount, 2);
      expect(plan.familyGroups, hasLength(1));
      expect(plan.familyGroups.first.match, ImportFamilyMatch.existing);
      expect(plan.familyGroups.first.matchedFamilyDbId, 42);
      expect(plan.familiesNeeded, 0);
    });

    test('unknown existing family ID invalidates the row', () {
      final withFamilyIdCol = columns({
        ImportCoreField.studentName: 0,
        ImportCoreField.existingFamilyId: 1,
      }, 2);
      final plan = planner.plan(
        sheetName: 'Students',
        columns: withFamilyIdCol,
        sheetRows: [
          ['Ali Khan', 'FAM-000999'],
        ],
        existingStudentIds: const {},
        existingAdmissionNumbers: const {},
        resolvedFamilyIds: {'fam-000999': null},
        dbStudents: const [],
        dbFamilies: const [],
      );
      expect(plan.rows.first.verdict, ImportRowVerdict.invalid);
      expect(plan.rows.first.errors, isNotEmpty);
    });

    test('1000 clean rows produce 1000 families with no errors', () {
      final data = <List<Object?>>[];
      for (var i = 0; i < 1000; i++) {
        data.add([
          'Student $i',
          'Guardian $i',
          '0300-${(1000000 + i)}',
          'ADM-$i',
          null,
        ]);
      }
      final plan = build(data);
      expect(plan.rows, hasLength(1000));
      expect(plan.validCount, 1000);
      expect(plan.invalidCount, 0);
      expect(plan.duplicateCount, 0);
      expect(plan.familyGroups, hasLength(1000));
    });
  });
}
