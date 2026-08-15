import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/import/domain/entities/column_mapping.dart';
import 'package:school_office_management/features/import/domain/entities/custom_field.dart';
import 'package:school_office_management/features/import/domain/entities/import_fields.dart';
import 'package:school_office_management/features/import/domain/entities/import_row.dart';
import 'package:school_office_management/features/import/domain/services/row_validator.dart';

void main() {
  final validator = RowValidator();

  List<ColumnMapping> coreColumns(Map<ImportCoreField, int> indexByField) {
    final width = indexByField.values.fold(0, (a, b) => a > b ? a : b) + 1;
    final byIndex = <int, ColumnMapping>{};
    for (final entry in indexByField.entries) {
      byIndex[entry.value] = ColumnMapping(
        index: entry.value,
        sourceHeader: entry.key.displayName,
        normalizedHeader: entry.key.displayName,
        kind: ColumnTargetKind.core,
        status: ColumnMatchStatus.autoMatched,
        coreField: entry.key,
      );
    }
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

  ColumnMapping customColumn(
    int index, {
    String name = 'blood_group',
    String entityType = 'student',
    CustomFieldDataType? dataType,
  }) {
    return ColumnMapping(
      index: index,
      sourceHeader: 'Blood Group',
      normalizedHeader: 'blood group',
      kind: ColumnTargetKind.custom,
      status: ColumnMatchStatus.unknown,
      customFieldName: name,
      customDisplayName: 'Blood Group',
      customEntityType: entityType,
      customDataType: dataType,
    );
  }

  group('RowValidator.validateRow', () {
    test('requires a student name', () {
      final columns = coreColumns(const {ImportCoreField.studentName: 0});
      final row = ImportRow(index: 0, rawValues: [null]);
      validator.validateRow(row, columns);
      expect(row.errors, isNotEmpty);
      expect(row.errors.first.field, 'Student Name');
    });

    test('parses core fields and trims text', () {
      final columns = coreColumns(const {
        ImportCoreField.studentName: 0,
        ImportCoreField.gender: 1,
        ImportCoreField.dateOfBirth: 2,
        ImportCoreField.className: 3,
        ImportCoreField.cnic: 4,
      });
      final row = ImportRow(
        index: 0,
        rawValues: [
          '  Ali Khan  ',
          'MALE',
          '15/08/2026',
          'Grade 5',
          '35202-1234567-1',
        ],
      );
      validator.validateRow(row, columns);
      expect(row.errors, isEmpty);
      expect(row.studentName, 'Ali Khan');
      expect(row.coreValues[ImportCoreField.gender], 'male');
      expect(
        row.coreValues[ImportCoreField.dateOfBirth],
        DateTime(2026, 8, 15),
      );
      expect(row.coreValues[ImportCoreField.className], 'Grade 5');
      expect(row.coreValues[ImportCoreField.cnic], '35202-1234567-1');
    });

    test('gender rejects unknown values', () {
      final columns = coreColumns(const {
        ImportCoreField.studentName: 0,
        ImportCoreField.gender: 1,
      });
      final row = ImportRow(index: 0, rawValues: ['Ayesha', 'Unknown']);
      validator.validateRow(row, columns);
      expect(row.errors, hasLength(1));
      expect(row.errors.first.field, 'Gender');
    });

    test('accepts date cells as DateTime and normalizes to a date', () {
      final columns = coreColumns(const {
        ImportCoreField.studentName: 0,
        ImportCoreField.admissionDate: 1,
      });
      final row = ImportRow(
        index: 0,
        rawValues: ['Sana', DateTime(2026, 8, 1, 14)],
      );
      validator.validateRow(row, columns);
      expect(row.errors, isEmpty);
      expect(
        row.coreValues[ImportCoreField.admissionDate],
        DateTime(2026, 8, 1),
      );
    });

    test('rejects unparseable dates', () {
      final columns = coreColumns(const {
        ImportCoreField.studentName: 0,
        ImportCoreField.dateOfBirth: 1,
      });
      final row = ImportRow(index: 0, rawValues: ['Sana', 'not a date']);
      validator.validateRow(row, columns);
      expect(row.errors, hasLength(1));
      expect(row.errors.first.field, 'Date of Birth');
    });

    test('admission fee must be a non-negative number', () {
      final columns = coreColumns(const {
        ImportCoreField.studentName: 0,
        ImportCoreField.admissionFee: 1,
      });
      final bad = ImportRow(index: 0, rawValues: ['Sana', '-5']);
      validator.validateRow(bad, columns);
      expect(bad.errors, isNotEmpty);
      expect(bad.errors.first.field, 'Admission Fee');

      final good = ImportRow(index: 0, rawValues: ['Sana', '1,500']);
      validator.validateRow(good, columns);
      expect(good.errors, isEmpty);
      expect(good.coreValues[ImportCoreField.admissionFee], 1500.0);
    });

    test('custom values are parsed by data type and never fail the row', () {
      final columns = [
        customColumn(0, name: 'siblings', dataType: CustomFieldDataType.number),
        customColumn(1, name: 'joined', dataType: CustomFieldDataType.date),
        customColumn(2, name: 'bus', dataType: CustomFieldDataType.boolean),
        ...coreColumns(const {ImportCoreField.studentName: 3}),
      ];
      final row = ImportRow(
        index: 0,
        rawValues: ['3', '2026-01-01', 'YES', 'Ali'],
      );
      validator.validateRow(row, columns);
      expect(row.errors, isEmpty);
      expect(row.customValues['siblings'], 3);
      expect(row.customValues['joined'], DateTime(2026, 1, 1));
      expect(row.customValues['bus'], true);
    });
  });

  group('RowValidator.inferCustomType', () {
    test('infers text when values are mixed', () {
      final rows = [
        ['a', '1'],
        ['b', 'hello'],
      ];
      expect(validator.inferCustomType(rows, 1), CustomFieldDataType.text);
    });

    test('infers number only for strict integers', () {
      final rows = [
        ['a', '12'],
        ['b', '007'],
      ];
      expect(validator.inferCustomType(rows, 1), CustomFieldDataType.number);
    });

    test('infers decimal for floating values', () {
      final rows = [
        ['a', '12.5'],
        ['b', '3.75'],
      ];
      expect(validator.inferCustomType(rows, 1), CustomFieldDataType.decimal);
    });

    test('infers boolean for yes/no values', () {
      final rows = [
        ['a', 'yes'],
        ['b', 'No'],
      ];
      expect(validator.inferCustomType(rows, 1), CustomFieldDataType.boolean);
    });

    test('infers date for parseable dates', () {
      final rows = [
        ['a', '15/08/2026'],
        ['b', '2026-08-16'],
      ];
      expect(validator.inferCustomType(rows, 1), CustomFieldDataType.date);
    });
  });
}
