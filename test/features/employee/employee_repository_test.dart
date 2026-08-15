import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:school_office_management/core/database/app_database.dart';
import 'package:school_office_management/features/employee/data/repositories/employee_repository_impl.dart';
import 'package:school_office_management/features/employee/domain/entities/employee_category.dart';
import 'package:school_office_management/features/employee/domain/entities/employee_salary_record.dart';
import 'package:school_office_management/features/employee/domain/entities/employee_status.dart';
import 'package:school_office_management/features/employee/domain/repositories/employee_has_salary_history_exception.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppDatabase? database;
  late EmployeeRepositoryImpl repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> openDb() async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    database = db;
    repository = EmployeeRepositoryImpl(db.raw);
  }

  tearDown(() async {
    await database?.close();
    database = null;
  });

  const ts = '2026-08-01T00:00:00Z';

  Future<int> insertEmployeeRaw({
    String id = 'EMP-000001',
    String name = 'Raw Name',
    String designation = 'Teacher',
    String category = 'teacher',
    String status = 'active',
    String? phone,
    double basicSalary = 0,
  }) async {
    return database!.raw.insert('employees', {
      'employee_id': id,
      'name': name,
      'designation': designation,
      'category': category,
      'contact': phone,
      'basic_salary': basicSalary,
      'status': status,
      'created_at': ts,
      'updated_at': ts,
    });
  }

  Future<void> insertSalaryRecord({
    required int employeeId,
    required String periodStart,
    required String periodEnd,
    double baseSalary = 0,
    double advance = 0,
    double deduction = 0,
    double netAmount = 0,
    String status = 'paid',
    String? paymentDate,
  }) async {
    await database!.raw.insert('salary_records', {
      'employee_id': employeeId,
      'period_start': periodStart,
      'period_end': periodEnd,
      'base_salary': baseSalary,
      'advance': advance,
      'deduction': deduction,
      'net_amount': netAmount,
      'payment_date': paymentDate,
      'status': status,
      'created_at': ts,
    });
  }

  group('create employee', () {
    test('creates an employee with a generated ID and normalized CNIC', () async {
      await openDb();
      final employee = await repository.createEmployee(
        name: '  Ahmed Khan  ',
        designation: '  Mathematics Teacher  ',
        category: EmployeeCategory.teacher,
        department: 'Science',
        phone: '0300-1234567',
        address: 'House 4, Main Street',
        cnic: '1234512345671',
        basicSalary: 25000,
      );

      expect(employee.employeeId, 'EMP-000001');
      expect(employee.name, 'Ahmed Khan');
      expect(employee.designation, 'Mathematics Teacher');
      expect(employee.category, EmployeeCategory.teacher);
      expect(employee.cnic, '12345-1234567-1');
      expect(employee.basicSalary, 25000);
      expect(employee.status, EmployeeStatus.active);

      final loaded = await repository.getEmployee(employee.id);
      expect(loaded?.employeeId, 'EMP-000001');
      expect(loaded?.department, 'Science');
      expect(loaded?.phone, '0300-1234567');
    });

    test('second employee gets the next sequential ID', () async {
      await openDb();
      await repository.createEmployee(
        name: 'First',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
      );
      final second = await repository.createEmployee(
        name: 'Second',
        designation: 'Clerk',
        category: EmployeeCategory.officeStaff,
      );
      expect(second.employeeId, 'EMP-000002');
    });

    test('rejects an empty name', () async {
      await openDb();
      await expectLater(
        repository.createEmployee(
          name: '   ',
          designation: 'Teacher',
          category: EmployeeCategory.teacher,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects an empty designation', () async {
      await openDb();
      await expectLater(
        repository.createEmployee(
          name: 'Ahmed',
          designation: '   ',
          category: EmployeeCategory.teacher,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a negative basic salary', () async {
      await openDb();
      await expectLater(
        repository.createEmployee(
          name: 'Ahmed',
          designation: 'Teacher',
          category: EmployeeCategory.teacher,
          basicSalary: -5,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('duplicate employee ID is rejected by the unique constraint', () async {
      await openDb();
      await repository.createEmployee(
        name: 'First',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
      );
      await expectLater(
        insertEmployeeRaw(id: 'EMP-000001'),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('omitted optional fields are stored as null with zero salary', () async {
      await openDb();
      final employee = await repository.createEmployee(
        name: 'Minimal',
        designation: 'Teacher',
        category: EmployeeCategory.otherStaff,
      );
      final loaded = await repository.getEmployee(employee.id);
      expect(loaded?.department, isNull);
      expect(loaded?.phone, isNull);
      expect(loaded?.address, isNull);
      expect(loaded?.cnic, isNull);
      expect(loaded?.joiningDate, isNull);
      expect(loaded?.notes, isNull);
      expect(loaded?.basicSalary, 0);
    });

    test('unknown stored category maps to otherStaff', () async {
      await openDb();
      await insertEmployeeRaw(category: 'librarian');
      final employee = await repository.getEmployeeByEmployeeId('EMP-000001');
      expect(employee?.category, EmployeeCategory.otherStaff);
    });
  });

  group('edit employee', () {
    test('updates fields but keeps the employee ID', () async {
      await openDb();
      final employee = await repository.createEmployee(
        name: 'Old Name',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
        cnic: '1234512345671',
      );
      final updated = await repository.updateEmployee(
        id: employee.id,
        name: 'New Name',
        designation: 'Head Teacher',
        category: EmployeeCategory.officeStaff,
        department: 'Admin',
        phone: '0300-7654321',
        cnic: '9876587654321',
        basicSalary: 30000,
      );

      expect(updated.employeeId, 'EMP-000001');
      expect(updated.name, 'New Name');
      expect(updated.designation, 'Head Teacher');
      expect(updated.category, EmployeeCategory.officeStaff);
      expect(updated.cnic, '98765-8765432-1');
      expect(updated.basicSalary, 30000);
    });

    test('deactivate and reactivate toggle the status', () async {
      await openDb();
      final employee = await repository.createEmployee(
        name: 'Ahmed',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
      );
      final inactive = await repository.deactivateEmployee(employee.id);
      expect(inactive.status, EmployeeStatus.inactive);
      expect(inactive.isArchived, isTrue);

      final active = await repository.reactivateEmployee(employee.id);
      expect(active.status, EmployeeStatus.active);
    });
  });

  group('delete employee', () {
    test('deletes an employee with no salary history', () async {
      await openDb();
      final employee = await repository.createEmployee(
        name: 'Ahmed',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
      );
      await repository.deleteEmployee(employee.id);
      expect(await repository.getEmployee(employee.id), isNull);
    });

    test('blocks deletion when salary history exists', () async {
      await openDb();
      final employee = await repository.createEmployee(
        name: 'Ahmed',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
      );
      await insertSalaryRecord(
        employeeId: employee.id,
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        netAmount: 20000,
      );

      await expectLater(
        repository.deleteEmployee(employee.id),
        throwsA(isA<EmployeeHasSalaryHistoryException>()),
      );
      expect(await repository.getEmployee(employee.id), isNotNull);
    });

    test('deleting a nonexistent employee is a no-op', () async {
      await openDb();
      await repository.deleteEmployee(9999);
    });

    test('salary record referencing a deleted employee is blocked by FK', () async {
      await openDb();
      final employee = await repository.createEmployee(
        name: 'Ahmed',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
      );
      await repository.deleteEmployee(employee.id);
      await expectLater(
        insertSalaryRecord(
          employeeId: employee.id,
          periodStart: '2026-08-01',
          periodEnd: '2026-08-31',
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('search and filter', () {
    test('empty query returns all employees ordered by employee ID', () async {
      await openDb();
      await repository.createEmployee(
        name: 'First',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
      );
      await repository.createEmployee(
        name: 'Second',
        designation: 'Clerk',
        category: EmployeeCategory.officeStaff,
      );
      final results = await repository.searchEmployees('');
      expect(results.map((e) => e.employeeId), ['EMP-000001', 'EMP-000002']);
    });

    test('search matches name, designation, employee ID and phone digits', () async {
      await openDb();
      await repository.createEmployee(
        name: 'Sara Ali',
        designation: 'Chemistry Teacher',
        category: EmployeeCategory.teacher,
        phone: '0300-1234567',
      );
      await repository.createEmployee(
        name: 'Usman',
        designation: 'Clerk',
        category: EmployeeCategory.officeStaff,
        phone: '0311-7654321',
      );

      expect((await repository.searchEmployees('sara')).length, 1);
      expect((await repository.searchEmployees('chemistry')).length, 1);
      expect((await repository.searchEmployees('EMP-000002')).length, 1);
      expect((await repository.searchEmployees('03001234567')).length, 1);
      expect((await repository.searchEmployees('no match')).length, 0);
    });

    test('category filter narrows results', () async {
      await openDb();
      await repository.createEmployee(
        name: 'A',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
      );
      await repository.createEmployee(
        name: 'B',
        designation: 'Clerk',
        category: EmployeeCategory.officeStaff,
      );
      final teachers = await repository.searchEmployees(
        '',
        category: EmployeeCategory.teacher,
      );
      expect(teachers.map((e) => e.name), ['A']);
    });

    test('status filter narrows results', () async {
      await openDb();
      final a = await repository.createEmployee(
        name: 'A',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
      );
      await repository.createEmployee(
        name: 'B',
        designation: 'Clerk',
        category: EmployeeCategory.officeStaff,
      );
      await repository.deactivateEmployee(a.id);

      final inactive = await repository.searchEmployees(
        '',
        status: EmployeeStatus.inactive,
      );
      expect(inactive.map((e) => e.name), ['A']);
      final active = await repository.searchEmployees(
        '',
        status: EmployeeStatus.active,
      );
      expect(active.map((e) => e.name), ['B']);
    });

    test('category and status filters combine', () async {
      await openDb();
      final a = await repository.createEmployee(
        name: 'A',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
      );
      await repository.createEmployee(
        name: 'B',
        designation: 'Clerk',
        category: EmployeeCategory.officeStaff,
      );
      await repository.deactivateEmployee(a.id);

      final results = await repository.searchEmployees(
        '',
        category: EmployeeCategory.teacher,
        status: EmployeeStatus.active,
      );
      expect(results, isEmpty);
    });

    test('limit caps the number of results', () async {
      await openDb();
      for (var i = 1; i <= 5; i++) {
        await repository.createEmployee(
          name: 'Staff $i',
          designation: 'Teacher',
          category: EmployeeCategory.teacher,
        );
      }
      final results = await repository.searchEmployees('', limit: 2);
      expect(results.length, 2);
    });
  });

  group('duplicate detection', () {
    test('same phone flags a duplicate even with a different name', () async {
      await openDb();
      await repository.createEmployee(
        name: 'Ahmed',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
        phone: '03001234567',
      );
      final duplicates = await repository.findPossibleDuplicates(
        name: 'Someone Else',
        phone: '0300-1234567',
      );
      expect(duplicates.map((e) => e.name), ['Ahmed']);
    });

    test('same name and phone flags a duplicate; different phone does not', () async {
      await openDb();
      await repository.createEmployee(
        name: 'Sara Ali',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
        phone: '03001234567',
      );

      final samePhone = await repository.findPossibleDuplicates(
        name: 'Sara Ali',
        phone: '0300-1234567',
      );
      expect(samePhone.length, 1);

      final differentPhone = await repository.findPossibleDuplicates(
        name: 'Sara Ali',
        phone: '0311-1111111',
      );
      expect(differentPhone, isEmpty);
    });

    test('same name and CNIC flags a duplicate', () async {
      await openDb();
      await repository.createEmployee(
        name: 'Ahmed',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
        cnic: '1234512345671',
      );
      final duplicates = await repository.findPossibleDuplicates(
        name: 'Ahmed',
        cnic: '12345-1234567-1',
      );
      expect(duplicates.length, 1);
    });

    test('excludeId skips the employee being edited', () async {
      await openDb();
      final a = await repository.createEmployee(
        name: 'A',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
        phone: '03001234567',
      );
      await repository.createEmployee(
        name: 'B',
        designation: 'Clerk',
        category: EmployeeCategory.officeStaff,
        phone: '03001234567',
      );
      final duplicates = await repository.findPossibleDuplicates(
        excludeId: a.id,
        phone: '03001234567',
      );
      expect(duplicates.map((e) => e.name), ['B']);
    });
  });

  group('employee details', () {
    test('returns employee, salary history and paid/pending totals', () async {
      await openDb();
      final employee = await repository.createEmployee(
        name: 'Ahmed',
        designation: 'Teacher',
        category: EmployeeCategory.teacher,
        basicSalary: 25000,
      );
      await insertSalaryRecord(
        employeeId: employee.id,
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        baseSalary: 25000,
        netAmount: 23500,
        status: 'paid',
        paymentDate: '2026-08-31',
      );
      await insertSalaryRecord(
        employeeId: employee.id,
        periodStart: '2026-09-01',
        periodEnd: '2026-09-30',
        baseSalary: 25000,
        netAmount: 25000,
        status: 'pending',
      );

      final details = await repository.getEmployeeDetails(employee.id);
      expect(details.employee.employeeId, 'EMP-000001');
      expect(details.salaryRecordCount, 2);
      expect(details.salaryHistory.first.periodStart.year, 2026);
      expect(details.salaryHistory.first.periodStart.month, 9);
      expect(details.totalPaid, 23500);
      expect(details.totalPending, 25000);
      expect(details.salaryHistory.first.status, SalaryStatus.pending);
      expect(details.salaryHistory.last.status, SalaryStatus.paid);
      expect(details.salaryHistory.last.paymentDate, isNotNull);
    });

    test('throws when the employee does not exist', () async {
      await openDb();
      await expectLater(
        repository.getEmployeeDetails(9999),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('restart persistence', () {
    test('employee ID sequence survives a close and reopen', () async {
      final dir = await Directory.systemTemp.createTemp('employee_test_');
      final path = p.join(dir.path, 'test.db');
      try {
        final firstDb = await AppDatabase.open(path: path);
        final firstRepo = EmployeeRepositoryImpl(firstDb.raw);
        await firstRepo.createEmployee(
          name: 'One',
          designation: 'Teacher',
          category: EmployeeCategory.teacher,
        );
        await firstDb.close();

        final secondDb = await AppDatabase.open(path: path);
        final secondRepo = EmployeeRepositoryImpl(secondDb.raw);
        final second = await secondRepo.createEmployee(
          name: 'Two',
          designation: 'Clerk',
          category: EmployeeCategory.officeStaff,
        );
        expect(second.employeeId, 'EMP-000002');
        await secondDb.close();
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
