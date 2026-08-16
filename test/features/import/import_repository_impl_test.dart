import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/core/database/app_database.dart';
import 'package:school_office_management/features/import/data/repositories/import_repository_impl.dart';
import 'package:school_office_management/features/import/domain/entities/column_mapping.dart';
import 'package:school_office_management/features/import/domain/entities/custom_field.dart';
import 'package:school_office_management/features/import/domain/entities/import_family_group.dart';
import 'package:school_office_management/features/import/domain/entities/import_fields.dart';
import 'package:school_office_management/features/import/domain/entities/import_plan.dart';
import 'package:school_office_management/features/import/domain/entities/import_row.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppDatabase? database;
  late ImportRepositoryImpl repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> openDb() async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    database = db;
    repository = ImportRepositoryImpl(db.raw);
  }

  tearDown(() async {
    await database?.close();
    database = null;
  });

  const ts = '2026-08-01T00:00:00Z';

  ImportRow makeRow(
    int index,
    String name, {
    String? guardian,
    String? phone,
    String? admissionNumber,
    Map<ImportCoreField, Object?> extra = const {},
    Map<String, Object?> custom = const {},
    ImportRowVerdict verdict = ImportRowVerdict.valid,
  }) {
    final row = ImportRow(index: index, rawValues: [name]);
    row.coreValues[ImportCoreField.studentName] = name;
    row.coreValues[ImportCoreField.guardianName] = guardian;
    row.coreValues[ImportCoreField.primaryPhone] = phone;
    if (admissionNumber != null) {
      row.coreValues[ImportCoreField.admissionNumber] = admissionNumber;
    }
    row.coreValues.addAll(extra);
    row.customValues.addAll(custom);
    row.verdict = verdict;
    return row;
  }

  ImportFamilyGroup makeGroup(
    String guardian, {
    List<int> rows = const [],
    ImportFamilyMatch match = ImportFamilyMatch.none,
    int? matchedFamilyDbId,
  }) {
    final group = ImportFamilyGroup(guardianName: guardian);
    group.rowIndices.addAll(rows);
    group.match = match;
    group.matchedFamilyDbId = matchedFamilyDbId;
    return group;
  }

  ColumnMapping coreColumn(int index, ImportCoreField field) {
    return ColumnMapping(
      index: index,
      sourceHeader: field.displayName,
      normalizedHeader: field.displayName,
      kind: ColumnTargetKind.core,
      status: ColumnMatchStatus.autoMatched,
      coreField: field,
    );
  }

  ColumnMapping customColumn(
    int index,
    String fieldName,
    String displayName, {
    String entityType = 'student',
  }) {
    return ColumnMapping(
      index: index,
      sourceHeader: displayName,
      normalizedHeader: displayName,
      kind: ColumnTargetKind.custom,
      status: ColumnMatchStatus.unknown,
      customFieldName: fieldName,
      customDisplayName: displayName,
      customEntityType: entityType,
    );
  }

  ImportPlan plan({
    required List<ColumnMapping> columns,
    required List<ImportRow> rows,
    required List<ImportFamilyGroup> familyGroups,
  }) {
    return ImportPlan(
      sheetName: 'Students',
      columns: columns,
      rows: rows,
      familyGroups: familyGroups,
    );
  }

  group('custom field definitions', () {
    test('createCustomField persists a sequential definition', () async {
      await openDb();
      final def = await repository.createCustomField(
        entityType: 'student',
        fieldName: 'blood_group',
        displayName: 'Blood Group',
        dataType: CustomFieldDataType.text,
      );

      expect(def.definitionId, 'CFD-000001');
      expect(def.entityType, 'student');
      expect(def.fieldName, 'blood_group');
      expect(def.dataType, CustomFieldDataType.text);
      expect(def.isActive, isTrue);

      final all = await repository.listCustomFields();
      expect(all, hasLength(1));
      final filtered = await repository.listCustomFields(entityType: 'family');
      expect(filtered, isEmpty);
      final activeOnly = await repository.listCustomFields(activeOnly: false);
      expect(activeOnly, hasLength(1));
    });

    test(
      'findCustomField matches by field name or display name, normalized',
      () async {
        await openDb();
        await repository.createCustomField(
          entityType: 'student',
          fieldName: 'blood_group',
          displayName: 'Blood Group',
          dataType: CustomFieldDataType.text,
        );

        final byField = await repository.findCustomField(
          'student',
          'Blood Group',
        );
        expect(byField, isNotNull);
        expect(byField!.fieldName, 'blood_group');
        final byDisplay = await repository.findCustomField(
          'student',
          'blood_group',
        );
        expect(byDisplay, isNotNull);
        final wrongType = await repository.findCustomField(
          'family',
          'Blood Group',
        );
        expect(wrongType, isNull);
      },
    );

    test('saveCustomFieldValue inserts then updates in place', () async {
      await openDb();
      final def = await repository.createCustomField(
        entityType: 'student',
        fieldName: 'blood_group',
        displayName: 'Blood Group',
        dataType: CustomFieldDataType.text,
      );

      await repository.saveCustomFieldValue(
        definitionId: def.id,
        entityType: 'student',
        entityId: 7,
        value: 'B+',
      );
      await repository.saveCustomFieldValue(
        definitionId: def.id,
        entityType: 'student',
        entityId: 7,
        value: 'O-',
      );
      await repository.saveCustomFieldValue(
        definitionId: def.id,
        entityType: 'student',
        entityId: 8,
        value: 'A+',
      );

      final values = await repository.allCustomFieldValuesFor(
        entityType: 'student',
        entityIds: [7, 8],
      );
      expect(values['blood_group'], {7: 'O-', 8: 'A+'});

      final count = await database!.raw.query(
        'custom_field_values',
        where: 'definition_id = ?',
        whereArgs: [def.id],
      );
      expect(count, hasLength(2));
    });
  });

  group('importPlan', () {
    test('imports groups with sequential IDs and admission fee', () async {
      await openDb();
      final result = await repository.importPlan(
        plan(
          columns: const [],
          rows: [
            makeRow(
              0,
              'Ali Khan',
              guardian: 'Ahmed Khan',
              admissionNumber: 'ADM-2024-100',
            ),
            makeRow(
              1,
              'Sana Khan',
              guardian: 'Ahmed Khan',
              admissionNumber: 'ADM-2024-101',
            ),
          ],
          familyGroups: [
            makeGroup('Ahmed Khan', rows: [0, 1]),
          ],
        ),
      );

      expect(result.importedFamilies, 1);
      expect(result.importedStudents, 2);
      expect(result.skippedDuplicates, 0);
      expect(result.skippedInvalid, 0);
      expect(result.failures, isEmpty);

      final families = await database!.raw.query('families');
      expect(families.single['family_id'], 'FAM-000001');
      expect(families.single['guardian_name'], 'Ahmed Khan');

      final students = await database!.raw.query('students', orderBy: 'id');
      expect(students[0]['student_id'], 'STU-000001');
      expect(students[0]['name'], 'Ali Khan');
      expect(students[1]['student_id'], 'STU-000002');
      expect(students[1]['admission_number'], 'ADM-2024-101');

      final admissions = await database!.raw.query('admissions', orderBy: 'id');
      expect(admissions[0]['admission_id'], 'ADM-000001');
      expect(admissions[0]['student_id'], students[0]['id']);
    });

    test('creates custom fields once and stores values idempotently', () async {
      await openDb();
      final columns = [
        coreColumn(0, ImportCoreField.studentName),
        customColumn(1, 'blood_group', 'Blood Group'),
        customColumn(2, 'bus_route', 'Bus Route', entityType: 'family'),
      ];
      final rows = [
        makeRow(
          0,
          'Ali Khan',
          guardian: 'Ahmed Khan',
          custom: {'blood_group': 'B+', 'bus_route': 'Route 1'},
        ),
        makeRow(
          1,
          'Sana Khan',
          guardian: 'Ahmed Khan',
          custom: {'blood_group': 'O-', 'bus_route': 'Route 2'},
        ),
      ];
      final groups = [
        makeGroup('Ahmed Khan', rows: [0, 1]),
      ];

      final first = await repository.importPlan(
        plan(columns: columns, rows: rows, familyGroups: groups),
      );
      expect(first.createdCustomFields, ['Blood Group', 'Bus Route']);

      final defs = await repository.listCustomFields();
      expect(defs, hasLength(2));

      final students = await database!.raw.query('students', orderBy: 'id');
      final studentValues = await repository.allCustomFieldValuesFor(
        entityType: 'student',
        entityIds: students.map((s) => s['id'] as int).toList(),
      );
      expect(studentValues['blood_group'], {
        students[0]['id'] as int: 'B+',
        students[1]['id'] as int: 'O-',
      });

      final families = await database!.raw.query('families');
      final familyValues = await repository.allCustomFieldValuesFor(
        entityType: 'family',
        entityIds: [families.single['id'] as int],
      );
      expect(familyValues['bus_route'], {
        families.single['id'] as int: 'Route 1',
      });

      final second = await repository.importPlan(
        plan(columns: columns, rows: rows, familyGroups: groups),
      );
      expect(second.createdCustomFields, isEmpty);
      expect(await repository.listCustomFields(), hasLength(2));
    });

    test(
      'skips possible duplicates by default and includes them when asked',
      () async {
        await openDb();
        final rows = [
          makeRow(0, 'Ali Khan', guardian: 'Ahmed Khan'),
          makeRow(
            1,
            'Sana Khan',
            guardian: 'Ahmed Khan',
            verdict: ImportRowVerdict.possibleDuplicate,
          ),
        ];
        final groups = [
          makeGroup('Ahmed Khan', rows: [0, 1]),
        ];

        final skipped = await repository.importPlan(
          plan(columns: const [], rows: rows, familyGroups: groups),
        );
        expect(skipped.importedStudents, 1);
        expect(skipped.skippedDuplicates, 1);

        final included = await repository.importPlan(
          plan(columns: const [], rows: rows, familyGroups: groups),
          includePossibleDuplicates: true,
        );
        expect(included.importedStudents, 2);
        expect(included.skippedDuplicates, 0);
      },
    );

    test(
      'attaches students to an existing family without creating a new one',
      () async {
        await openDb();
        final familyId = await database!.raw.insert('families', {
          'family_id': 'FAM-000001',
          'guardian_name': 'Existing Guardian',
          'created_at': ts,
          'updated_at': ts,
        });

        final result = await repository.importPlan(
          plan(
            columns: const [],
            rows: [makeRow(0, 'Ali Khan', guardian: 'Ahmed Khan')],
            familyGroups: [
              makeGroup(
                'Ahmed Khan',
                rows: [0],
                match: ImportFamilyMatch.existing,
                matchedFamilyDbId: familyId,
              ),
            ],
          ),
        );

        expect(result.importedFamilies, 0);
        expect(result.importedStudents, 1);
        final students = await database!.raw.query('students');
        expect(students.single['family_id'], familyId);
        expect(await database!.raw.query('families'), hasLength(1));
      },
    );

    test(
      'a per-row constraint failure is recorded and other rows still import',
      () async {
        await openDb();
        // Group 1 is a valid new family. Group 2 references a family id that
        // does not exist, so its student insert violates the FK constraint.
        final result = await repository.importPlan(
          plan(
            columns: const [],
            rows: [
              makeRow(0, 'Ali Khan', guardian: 'Ahmed Khan'),
              makeRow(1, 'Sana Khan', guardian: 'Orphan Guardian'),
            ],
            familyGroups: [
              makeGroup('Ahmed Khan', rows: [0]),
              makeGroup(
                'Orphan Guardian',
                rows: [1],
                match: ImportFamilyMatch.existing,
                matchedFamilyDbId: 999999,
              ),
            ],
          ),
        );

        expect(result.importedStudents, 1);
        expect(result.importedFamilies, 1);
        expect(result.failures, hasLength(1));
        expect(result.succeeded, isFalse);
        expect(await database!.raw.query('students'), hasLength(1));
        expect(await database!.raw.query('families'), hasLength(1));
      },
    );

    test('progress callback reports processed and total', () async {
      await openDb();
      final progress = <(int, int)>[];
      await repository.importPlan(
        plan(
          columns: const [],
          rows: [
            makeRow(0, 'Ali Khan', guardian: 'Ahmed Khan'),
            makeRow(1, 'Sana Khan', guardian: 'Ahmed Khan'),
          ],
          familyGroups: [
            makeGroup('Ahmed Khan', rows: [0, 1]),
          ],
        ),
        onProgress: (p, t) => progress.add((p, t)),
      );

      expect(progress, isNotEmpty);
      expect(progress.last, (2, 2));
    });
  });

  group('dedup and lookup helpers', () {
    test('existing IDs and dedup records reflect the database', () async {
      await openDb();
      await database!.raw.insert('families', {
        'family_id': 'FAM-000001',
        'guardian_name': 'Ahmed Khan',
        'phone': '0300-1234567',
        'cnic': '42201-1234567-1',
        'created_at': ts,
        'updated_at': ts,
      });
      await database!.raw.insert('students', {
        'student_id': 'STU-000001',
        'family_id': 1,
        'name': 'Ali Khan',
        'admission_number': 'ADM-100',
        'status': 'active',
        'created_at': ts,
        'updated_at': ts,
      });

      expect(await repository.existingStudentIds(), {'STU-000001'});
      expect(await repository.existingAdmissionNumbers(), {'adm-100'});
      expect(await repository.findFamilyIdByFamilyId('  fam-000001 '), 1);

      final students = await repository.studentsForDedup();
      expect(students.single.studentId, 'STU-000001');
      expect(students.single.admissionNumber, 'ADM-100');
      expect(students.single.primaryPhone, '0300-1234567');

      final families = await repository.familiesForDedup();
      expect(families.single.cnic, '42201-1234567-1');
    });
  });

  group('exportRows', () {
    test('picks the latest admission and maps all fields', () async {
      await openDb();
      await database!.raw.insert('families', {
        'family_id': 'FAM-000001',
        'guardian_name': 'Ahmed Khan',
        'mother_name': 'Fatima',
        'phone': '0300-1234567',
        'address': 'Street 5',
        'cnic': '42201-1234567-1',
        'created_at': ts,
        'updated_at': ts,
      });
      final studentId = await database!.raw.insert('students', {
        'student_id': 'STU-000001',
        'family_id': 1,
        'name': 'Ali Khan',
        'gender': 'male',
        'admission_number': 'ADM-100',
        'admission_date': '2024-03-01T00:00:00.000',
        'class': '5',
        'section': 'A',
        'status': 'active',
        'created_at': ts,
        'updated_at': ts,
      });
      await database!.raw.insert('admissions', {
        'admission_id': 'ADM-000001',
        'student_id': studentId,
        'admission_number': 'ADM-100',
        'admission_date': '2024-03-01T00:00:00.000',
        'class': '5',
        'section': 'A',
        'created_at': ts,
      });
      await database!.raw.insert('admissions', {
        'admission_id': 'ADM-000002',
        'student_id': studentId,
        'admission_number': 'ADM-100',
        'admission_date': '2026-08-01T00:00:00.000',
        'class': '5',
        'section': 'A',
        'admission_fee': 15000,
        'created_at': ts,
      });

      final rows = await repository.exportRows();
      final row = rows.single;
      expect(row.studentId, 'STU-000001');
      expect(row.familyIdText, 'FAM-000001');
      expect(row.guardianName, 'Ahmed Khan');
      expect(row.primaryPhone, '0300-1234567');
      expect(row.admissionNumber, 'ADM-100');
      expect(row.admissionFee, 15000);
      expect(row.admissionDate, DateTime(2024, 3, 1));
      expect(row.status, 'active');
    });
  });
}
