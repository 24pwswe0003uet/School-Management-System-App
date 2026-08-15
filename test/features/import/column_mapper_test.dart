import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/import/domain/entities/column_mapping.dart';
import 'package:school_office_management/features/import/domain/entities/custom_field.dart';
import 'package:school_office_management/features/import/domain/entities/import_fields.dart';
import 'package:school_office_management/features/import/domain/services/column_mapper.dart';

void main() {
  final mapper = ColumnMapper();

  final customField = CustomFieldDefinition(
    id: 1,
    definitionId: 'CFD-000001',
    entityType: 'student',
    fieldName: 'blood_group',
    displayName: 'Blood Group',
    dataType: CustomFieldDataType.text,
    isActive: true,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
  group('ColumnMapper.mapColumns', () {
    test('exact alias headers map to core fields automatically', () {
      final columns = mapper.mapColumns(const [
        'Student Name',
        'Gender',
        'Date of Birth',
        'Class',
      ], customFields: const []);
      expect(columns[0].kind, ColumnTargetKind.core);
      expect(columns[0].coreField, ImportCoreField.studentName);
      expect(columns[0].status, ColumnMatchStatus.autoMatched);
      expect(columns[1].coreField, ImportCoreField.gender);
      expect(columns[2].coreField, ImportCoreField.dateOfBirth);
      expect(columns[3].coreField, ImportCoreField.className);
    });

    test('aliases normalize punctuation and casing', () {
      final columns = mapper.mapColumns(const [
        'fatheR,s name',
        'Admission No.',
        'B-Form',
      ], customFields: const []);
      expect(columns[0].coreField, ImportCoreField.guardianName);
      expect(columns[1].coreField, ImportCoreField.admissionNumber);
      expect(columns[2].coreField, ImportCoreField.cnic);
    });

    test('existing custom fields match by name or display name', () {
      final columns = mapper.mapColumns(
        const ['Blood Group', 'blood_group'],
        customFields: [customField],
      );
      for (final column in columns) {
        expect(column.kind, ColumnTargetKind.custom);
        expect(column.customFieldName, 'blood_group');
        expect(column.status, ColumnMatchStatus.autoMatched);
      }
    });

    test('unknown columns become custom fields (never rejected)', () {
      final columns = mapper.mapColumns(const [
        'Transport Route',
        'Meal Preference',
      ], customFields: const []);
      expect(columns[0].kind, ColumnTargetKind.custom);
      expect(columns[0].customFieldName, 'transport_route');
      expect(columns[1].customFieldName, 'meal_preference');
      expect(columns[0].status, ColumnMatchStatus.unknown);
    });

    test('duplicate custom slugs get a numeric suffix', () {
      final columns = mapper.mapColumns(const [
        'Transport Route',
        'Transport Route',
      ], customFields: const []);
      expect(columns[0].customFieldName, 'transport_route');
      expect(columns[1].customFieldName, 'transport_route_2');
    });

    test('empty headers become ignored columns', () {
      final columns = mapper.mapColumns(const [
        'Student Name',
        '',
        'Notes',
      ], customFields: const []);
      expect(columns[0].kind, ColumnTargetKind.core);
      expect(columns[1].kind, ColumnTargetKind.ignored);
      expect(columns[2].kind, ColumnTargetKind.core);
    });

    test('whole-word aliases are suggested (not auto-applied)', () {
      final columns = mapper.mapColumns(const [
        'Student Admission Number',
      ], customFields: const []);
      expect(columns[0].kind, ColumnTargetKind.core);
      expect(columns[0].coreField, ImportCoreField.admissionNumber);
      expect(columns[0].status, ColumnMatchStatus.suggested);
    });

    test('round-trip: every export header maps to its core field', () {
      const exportHeaders = [
        'Student ID',
        'Student Name',
        'Gender',
        'Date of Birth',
        'Class',
        'Section',
        'Admission Number',
        'Admission Date',
        'Admission Fee',
        'Contact Reference',
        'Notes',
        'Family ID',
        'Guardian Name',
        'Mother Name',
        'Primary Phone',
        'Secondary Phone',
        'Address',
        'CNIC',
      ];
      final columns = mapper.mapColumns(exportHeaders, customFields: const []);
      for (final column in columns) {
        expect(
          column.kind,
          ColumnTargetKind.core,
          reason: 'header "${column.sourceHeader}" should map to a core field',
        );
      }
    });
  });
}
