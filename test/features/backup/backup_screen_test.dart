import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_office_management/features/backup/presentation/backup_screen.dart';
import 'package:school_office_management/features/backup/domain/services/data_export_service.dart';

import '../employee/fakes/fake_employee_repository.dart';
import '../expense/fakes/fake_expense_repository.dart';
import '../family/fakes/fake_family_repository.dart';
import '../fee/fakes/fake_fee_repository.dart';
import '../salary/fakes/fake_salary_repository.dart';
import '../student/fakes/fake_student_repository.dart';
import 'helpers.dart';

DataExportService _exportService() => DataExportService(
      students: FakeStudentRepository(),
      families: FakeFamilyRepository(),
      employees: FakeEmployeeRepository(),
      salaries: FakeSalaryRepository(),
      expenses: FakeExpenseRepository(),
      fees: FakeFeeRepository(),
      saveFile: ({
        required fileName,
        required bytes,
        dialogTitle,
        extension,
      }) =>
          Future.value('saved'),
    );

void main() {
  testWidgets('admin sees backup + export controls', (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    final service = await buildBackupService(database: db);
    await service.reload();

    await tester.pumpWidget(
      MaterialApp(
        home: BackupScreen(
          service: service,
          dataExportService: _exportService(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('create_backup')), findsOneWidget);
    expect(find.byKey(const Key('export_students')), findsOneWidget);
    expect(find.text('No backups found yet.'), findsOneWidget);
    expect(find.text('Administrator access required'), findsNothing);
  });

  testWidgets('non-admin sees a permission banner instead of controls',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    final service = await buildBackupService(
      database: db,
      authService: await buildTestDataEntryAuthService(),
    );
    await service.reload();

    await tester.pumpWidget(
      MaterialApp(
        home: BackupScreen(
          service: service,
          dataExportService: _exportService(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Administrator access required'), findsOneWidget);
    expect(find.byKey(const Key('create_backup')), findsNothing);
    expect(find.byKey(const Key('export_students')), findsNothing);
  });
}
