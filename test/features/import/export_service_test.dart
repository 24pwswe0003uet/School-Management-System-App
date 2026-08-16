import 'dart:convert';
import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/import/domain/entities/custom_field.dart';
import 'package:school_office_management/features/import/domain/entities/export_student_row.dart';
import 'package:school_office_management/features/import/domain/entities/import_fields.dart';
import 'package:school_office_management/features/import/domain/entities/import_plan.dart';
import 'package:school_office_management/features/import/domain/entities/import_row.dart';
import 'package:school_office_management/features/import/domain/services/export_service.dart';

import 'fakes/fake_import_repository.dart';

void main() {
  final ts = DateTime.utc(2026, 1, 1);
  final familyDef = CustomFieldDefinition(
    id: 1,
    definitionId: 'CFD-000001',
    entityType: 'family',
    fieldName: 'bus_route',
    displayName: 'Bus Route',
    dataType: CustomFieldDataType.text,
    isActive: true,
    createdAt: ts,
    updatedAt: ts,
  );
  final studentDef = CustomFieldDefinition(
    id: 2,
    definitionId: 'CFD-000002',
    entityType: 'student',
    fieldName: 'blood_group',
    displayName: 'Blood Group',
    dataType: CustomFieldDataType.text,
    isActive: true,
    createdAt: ts,
    updatedAt: ts,
  );
  const ali = ExportStudentRow(
    id: 1,
    studentId: 'STU-000001',
    name: 'Ali Khan',
    familyId: 1,
    familyIdText: 'FAM-000001',
    gender: 'male',
    dateOfBirth: null,
    admissionNumber: 'ADM-100',
    className: '5',
    section: 'A',
    admissionFee: 15000,
    guardianName: 'Ahmed Khan',
    primaryPhone: '0300-1234567',
  );

  group('exportStudents', () {
    test('writes an importable workbook with custom field columns', () async {
      final repo = FakeImportRepository()
        ..definitions.addAll([familyDef, studentDef])
        ..values[1] = {1: 'Route 1'}
        ..values[2] = {1: 'B+'}
        ..exportRowsResult = const [ali];

      String? savedPath;
      Uint8List? savedBytes;
      String? savedExtension;
      final service = ExportService(
        repo,
        saveFile:
            ({
              required String fileName,
              required Uint8List bytes,
              String? dialogTitle,
              String? extension,
            }) async {
              savedPath = fileName;
              savedBytes = bytes;
              savedExtension = extension;
              return 'C:/out/$fileName';
            },
      );

      final path = await service.exportStudents(
        suggestedFileName: 'school.xlsx',
      );
      expect(path, 'C:/out/school.xlsx');
      expect(savedPath, 'school.xlsx');
      expect(savedExtension, 'xlsx');
      expect(savedBytes, isNotNull);

      final workbook = Excel.decodeBytes(savedBytes!);
      final sheet = workbook['Students'];
      final headers = sheet.rows[0].map((c) => c?.value.toString()).toList();
      expect(headers, contains('Student ID'));
      expect(headers, contains('Student Name'));
      expect(headers, contains('Family ID'));
      expect(headers, contains('Guardian Name'));
      expect(headers, contains('Bus Route'));
      expect(headers, contains('Blood Group'));

      final dataRow = sheet.rows[1].map((c) => c?.value.toString()).toList();
      expect(dataRow[0], 'STU-000001');
      expect(dataRow[1], 'Ali Khan');
      expect(dataRow[headers.indexOf('Admission Fee')], '15000');
      expect(dataRow[headers.indexOf('Bus Route')], 'Route 1');
      expect(dataRow[headers.indexOf('Blood Group')], 'B+');
    });

    test('returns null when there is nothing to export', () async {
      final service = ExportService(FakeImportRepository());
      expect(await service.exportStudents(), isNull);
    });
  });

  group('exportErrorReport', () {
    ImportPlan planWithRows(List<ImportRow> rows) {
      return ImportPlan(
        sheetName: 'Students',
        columns: const [],
        rows: rows,
        familyGroups: const [],
      );
    }

    ImportRow invalidRow(int index, String name) {
      final row = ImportRow(index: index, rawValues: [name]);
      row.coreValues[ImportCoreField.studentName] = name;
      row.verdict = ImportRowVerdict.invalid;
      row.errors.add(const ImportRowError('Gender', 'Unknown value "x".'));
      return row;
    }

    ImportRow duplicateRow(int index, String name) {
      final row = ImportRow(index: index, rawValues: [name]);
      row.coreValues[ImportCoreField.studentName] = name;
      row.verdict = ImportRowVerdict.duplicate;
      row.verdictMessage = 'ADM-100 already exists.';
      return row;
    }

    test('writes a BOM-prefixed CSV with every skipped row', () async {
      final repo = FakeImportRepository();
      Uint8List? savedBytes;
      final service = ExportService(
        repo,
        saveFile:
            ({
              required String fileName,
              required Uint8List bytes,
              String? dialogTitle,
              String? extension,
            }) async {
              savedBytes = bytes;
              return 'C:/out/$fileName';
            },
      );

      final plan = planWithRows([
        invalidRow(0, 'Ali Khan'),
        duplicateRow(1, 'Sana Khan'),
      ]);
      final path = await service.exportErrorReport(plan);
      expect(path, endsWith('.csv'));

      expect(savedBytes!.take(3), [0xEF, 0xBB, 0xBF]);
      final text = utf8.decode(savedBytes!);
      expect(text, contains('Row,Student,Result,Details'));
      expect(text, contains('Ali Khan'));
      expect(text, contains('Invalid'));
      expect(text, contains('Unknown value'));
      expect(text, contains('Sana Khan'));
      expect(text, contains('ADM-100 already exists'));
    });

    test('formula markers in details are neutralised', () async {
      final repo = FakeImportRepository();
      Uint8List? savedBytes;
      final service = ExportService(
        repo,
        saveFile:
            ({
              required String fileName,
              required Uint8List bytes,
              String? dialogTitle,
              String? extension,
            }) async {
              savedBytes = bytes;
              return 'C:/out/$fileName';
            },
      );

      final row = ImportRow(index: 0, rawValues: const []);
      row.coreValues[ImportCoreField.studentName] = 'Ali Khan';
      row.verdict = ImportRowVerdict.duplicate;
      row.verdictMessage = '=HYPERLINK("evil")';
      final plan = planWithRows([row]);

      await service.exportErrorReport(plan);
      // CSV quoting doubles embedded quotes, so look for the guarded prefix.
      expect(utf8.decode(savedBytes!), contains("'=HYPERLINK"));
    });

    test('returns null when nothing was skipped', () async {
      final plan = ImportPlan(
        sheetName: 'Students',
        columns: const [],
        rows: [
          () {
            final r = ImportRow(index: 0, rawValues: const []);
            r.verdict = ImportRowVerdict.valid;
            return r;
          }(),
        ],
        familyGroups: const [],
      );
      final service = ExportService(FakeImportRepository());
      expect(await service.exportErrorReport(plan), isNull);
    });
  });
}
