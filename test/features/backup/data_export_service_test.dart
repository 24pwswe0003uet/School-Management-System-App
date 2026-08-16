import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/backup/domain/services/data_export_service.dart';
import 'package:school_office_management/features/family/domain/entities/family.dart';
import 'package:school_office_management/features/student/domain/entities/student.dart';

import '../employee/fakes/fake_employee_repository.dart';
import '../expense/fakes/fake_expense_repository.dart';
import '../family/fakes/fake_family_repository.dart';
import '../fee/fakes/fake_fee_repository.dart';
import '../salary/fakes/fake_salary_repository.dart';
import '../student/fakes/fake_student_repository.dart';

String? _savedName;
Uint8List? _savedBytes;
String? _savedExt;

Future<String?> _captureSaveFile({
  required String fileName,
  required Uint8List bytes,
  String? dialogTitle,
  String? extension,
}) async {
  _savedName = fileName;
  _savedBytes = bytes;
  _savedExt = extension;
  return 'saved.xlsx';
}

void main() {
  setUp(() {
    _savedName = null;
    _savedBytes = null;
    _savedExt = null;
  });

  DataExportService emptyService() => DataExportService(
        students: FakeStudentRepository(),
        families: FakeFamilyRepository(),
        employees: FakeEmployeeRepository(),
        salaries: FakeSalaryRepository(),
        expenses: FakeExpenseRepository(),
        fees: FakeFeeRepository(),
        saveFile: _captureSaveFile,
      );

  test('exporting empty data sets returns false and never saves', () async {
    final service = emptyService();
    expect(await service.exportStudents(), isFalse);
    expect(await service.exportFamilies(), isFalse);
    expect(await service.exportEmployees(), isFalse);
    expect(await service.exportFees(), isFalse);
    expect(await service.exportSalaries(), isFalse);
    expect(await service.exportExpenses(), isFalse);
    expect(_savedName, isNull);
  });

  test('exporting students saves an xlsx workbook with the rows', () async {
    final family = Family(
      id: 1,
      familyId: 'FAM-000001',
      guardianName: 'Ali',
      motherName: null,
      primaryPhone: null,
      secondaryPhone: null,
      address: null,
      cnic: null,
      notes: null,
      status: FamilyStatus.active,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final student = Student(
      id: 1,
      studentId: 'STU-000001',
      familyId: 1,
      name: 'Sara',
      gender: StudentGender.female,
      dateOfBirth: DateTime(2018, 5, 6),
      admissionNumber: 'ADM-001',
      admissionDate: DateTime(2026, 3, 1),
      className: '5',
      section: 'A',
      contactReference: null,
      notes: null,
      status: StudentStatus.active,
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );

    final service = DataExportService(
      students: FakeStudentRepository(
        students: [student],
        familyRepository: FakeFamilyRepository(families: [family]),
      ),
      families: FakeFamilyRepository(),
      employees: FakeEmployeeRepository(),
      salaries: FakeSalaryRepository(),
      expenses: FakeExpenseRepository(),
      fees: FakeFeeRepository(),
      saveFile: _captureSaveFile,
    );

    final saved = await service.exportStudents();
    expect(saved, isTrue);
    expect(_savedName, startsWith('students_export_'));
    expect(_savedName, endsWith('.xlsx'));
    expect(_savedExt, 'xlsx');
    expect(_savedBytes, isNotNull);
    expect(_savedBytes!.length, greaterThan(0));
  });

  test('exporting families saves an xlsx workbook', () async {
    final service = DataExportService(
      students: FakeStudentRepository(),
      families: FakeFamilyRepository(
        families: [
          Family(
            id: 1,
            familyId: 'FAM-000001',
            guardianName: 'Ali',
            motherName: null,
            primaryPhone: null,
            secondaryPhone: null,
            address: null,
            cnic: null,
            notes: null,
            status: FamilyStatus.active,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      ),
      employees: FakeEmployeeRepository(),
      salaries: FakeSalaryRepository(),
      expenses: FakeExpenseRepository(),
      fees: FakeFeeRepository(),
      saveFile: _captureSaveFile,
    );
    expect(await service.exportFamilies(), isTrue);
    expect(_savedName, endsWith('.xlsx'));
    expect(_savedBytes, isNotNull);
  });
}
