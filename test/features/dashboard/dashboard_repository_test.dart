import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/core/database/app_database.dart';
import 'package:school_office_management/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppDatabase? database;
  late DashboardRepositoryImpl repository;

  // Fixed "now" so date bucketing is deterministic.
  final now = DateTime(2026, 8, 14, 10, 30);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> openDb() async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    database = db;
    repository = DashboardRepositoryImpl(db.raw);
  }

  tearDown(() async {
    await database?.close();
    database = null;
  });

  Future<int> insertFamily({String id = 'FAM-000001'}) {
    return database!.raw.insert('families', {
      'family_id': id,
      'guardian_name': 'Guardian',
      'created_at': '2026-08-01T00:00:00Z',
      'updated_at': '2026-08-01T00:00:00Z',
    });
  }

  Future<int> insertStudent({
    required int familyId,
    String id = 'STU-000001',
    String name = 'Student One',
    String status = 'active',
  }) {
    return database!.raw.insert('students', {
      'student_id': id,
      'family_id': familyId,
      'name': name,
      'status': status,
      'created_at': '2026-08-01T00:00:00Z',
      'updated_at': '2026-08-01T00:00:00Z',
    });
  }

  Future<int> insertEmployee({
    String id = 'EMP-000001',
    String name = 'Teacher',
    String status = 'active',
  }) {
    return database!.raw.insert('employees', {
      'employee_id': id,
      'name': name,
      'status': status,
      'created_at': '2026-08-01T00:00:00Z',
      'updated_at': '2026-08-01T00:00:00Z',
    });
  }

  Future<int> insertFeeRecord({
    required int studentId,
    String id = 'FEE-000001',
    double expected = 5000,
    double discount = 0,
    double fine = 0,
    double paid = 0,
    String status = 'pending',
    String periodStart = '2026-08-01',
    String periodEnd = '2026-08-31',
  }) {
    final net = expected - discount + fine;
    final remaining = (net - paid).clamp(0, net).toDouble();
    return database!.raw.insert('fee_records', {
      'fee_record_id': id,
      'student_id': studentId,
      'period_start': periodStart,
      'period_end': periodEnd,
      'expected_amount': expected,
      'discount': discount,
      'fine': fine,
      'net_payable': net,
      'paid_amount': paid,
      'remaining_amount': remaining,
      'status': status,
      'created_at': '2026-08-01T00:00:00Z',
      'updated_at': '2026-08-01T00:00:00Z',
    });
  }

  Future<void> insertPayment({
    required int studentId,
    int? feeRecordId,
    required double amount,
    required String date,
    String id = 'PAY-000001',
  }) {
    return database!.raw.insert('payments', {
      'payment_id': id,
      'student_id': studentId,
      'fee_record_id': feeRecordId,
      'amount': amount,
      'payment_date': date,
      'created_at': '2026-08-01T00:00:00Z',
    });
  }

  Future<void> insertSalary({
    required int employeeId,
    required double net,
    required String? date,
    String status = 'paid',
    String periodStart = '2026-08-01',
  }) {
    return database!.raw.insert('salary_records', {
      'employee_id': employeeId,
      'period_start': periodStart,
      'period_end': '2026-08-31',
      'base_salary': net,
      'net_amount': net,
      'payment_date': date,
      'status': status,
      'created_at': '2026-08-01T00:00:00Z',
    });
  }

  Future<void> insertExpense({
    required double amount,
    required String date,
    String id = 'EXP-000001',
  }) {
    return database!.raw.insert('expenses', {
      'expense_id': id,
      'date': date,
      'amount': amount,
      'created_at': '2026-08-01T00:00:00Z',
    });
  }

  Future<void> insertAdmission({
    required int studentId,
    required String date,
    String id = 'ADM-000001',
    String className = '5',
  }) {
    return database!.raw.insert('admissions', {
      'admission_id': id,
      'student_id': studentId,
      'admission_date': date,
      'class': className,
      'created_at': '2026-08-01T00:00:00Z',
    });
  }

  group('empty database', () {
    test('returns all zeros, no activity, and isEmpty=true', () async {
      await openDb();
      final summary = await repository.load(now: now);

      expect(summary.activeStudents, 0);
      expect(summary.families, 0);
      expect(summary.activeEmployees, 0);
      expect(summary.todayCollection, 0);
      expect(summary.monthCollection, 0);
      expect(summary.outstandingFees, 0);
      expect(summary.monthSalary, 0);
      expect(summary.monthPendingSalary, 0);
      expect(summary.monthExpenses, 0);
      expect(summary.recentPayments, isEmpty);
      expect(summary.recentAdmissions, isEmpty);
      expect(summary.recentExpenses, isEmpty);
      expect(summary.isEmpty, isTrue);
      expect(summary.asOf, now);
    });
  });

  group('counts', () {
    test('counts active students only, excludes left/transferred', () async {
      await openDb();
      final familyId = await insertFamily();
      await insertStudent(familyId: familyId, id: 'STU-000001');
      await insertStudent(familyId: familyId, id: 'STU-000002');
      await insertStudent(familyId: familyId, id: 'STU-000003', status: 'left');
      await insertStudent(
        familyId: familyId,
        id: 'STU-000004',
        status: 'transferred',
      );

      final summary = await repository.load(now: now);
      expect(summary.activeStudents, 2);
      expect(summary.families, 1);
    });

    test('counts families', () async {
      await openDb();
      await insertFamily(id: 'FAM-000001');
      await insertFamily(id: 'FAM-000002');
      final summary = await repository.load(now: now);
      expect(summary.families, 2);
    });

    test('counts active families only, excludes archived', () async {
      await openDb();
      await insertFamily(id: 'FAM-000001');
      await insertFamily(id: 'FAM-000002');
      await database!.raw.update(
        'families',
        {'status': 'inactive'},
        where: 'family_id = ?',
        whereArgs: ['FAM-000002'],
      );
      final summary = await repository.load(now: now);
      expect(summary.families, 1);
    });

    test('counts active employees only', () async {
      await openDb();
      await insertEmployee(id: 'EMP-000001');
      await insertEmployee(id: 'EMP-000002');
      await insertEmployee(id: 'EMP-000003', status: 'inactive');
      final summary = await repository.load(now: now);
      expect(summary.activeEmployees, 2);
    });
  });

  group('collections', () {
    test('today and current month collections', () async {
      await openDb();
      final familyId = await insertFamily();
      final studentId = await insertStudent(familyId: familyId);

      await insertPayment(
        studentId: studentId,
        amount: 1000,
        date: '2026-08-14',
        id: 'PAY-000001',
      );
      await insertPayment(
        studentId: studentId,
        amount: 500,
        date: '2026-08-02',
        id: 'PAY-000002',
      );
      await insertPayment(
        studentId: studentId,
        amount: 2000,
        date: '2026-07-20',
        id: 'PAY-000003',
      );

      final summary = await repository.load(now: now);
      expect(summary.todayCollection, 1000);
      expect(summary.monthCollection, 1500);
    });

    test('month bucket switches with the reference date', () async {
      await openDb();
      final familyId = await insertFamily();
      final studentId = await insertStudent(familyId: familyId);
      await insertPayment(
        studentId: studentId,
        amount: 400,
        date: '2026-07-31',
        id: 'PAY-1',
      );

      final inJuly = await repository.load(now: DateTime(2026, 7, 31, 9));
      expect(inJuly.monthCollection, 400);

      final inAugust = await repository.load(now: DateTime(2026, 8, 1, 9));
      expect(inAugust.monthCollection, 0);
    });
  });

  group('outstanding fees', () {
    test(
      'pending + partial minus paid, excluding paid and cancelled',
      () async {
        await openDb();
        final familyId = await insertFamily();
        final studentId = await insertStudent(familyId: familyId);

        await insertFeeRecord(
          studentId: studentId,
          id: 'FEE-000001',
          expected: 5000,
          status: 'pending',
        );
        final partialFee = await insertFeeRecord(
          studentId: studentId,
          id: 'FEE-000002',
          expected: 3000,
          status: 'partial',
          paid: 1000,
          periodStart: '2026-09-01',
          periodEnd: '2026-09-30',
        );
        await insertFeeRecord(
          studentId: studentId,
          id: 'FEE-000003',
          expected: 2000,
          status: 'paid',
          periodStart: '2026-10-01',
          periodEnd: '2026-10-31',
        );
        await insertFeeRecord(
          studentId: studentId,
          id: 'FEE-000004',
          expected: 9999,
          status: 'cancelled',
          periodStart: '2026-11-01',
          periodEnd: '2026-11-30',
        );

        await insertPayment(
          studentId: studentId,
          feeRecordId: partialFee,
          amount: 1000,
          date: '2026-08-10',
          id: 'PAY-000001',
        );

        final summary = await repository.load(now: now);
        expect(summary.outstandingFees, 7000);
      },
    );

    test('reads the stored remaining balance, not a derived total', () async {
      await openDb();
      final familyId = await insertFamily();
      final studentId = await insertStudent(familyId: familyId);
      final feeId = await insertFeeRecord(
        studentId: studentId,
        id: 'FEE-000001',
        expected: 5000,
        paid: 2000,
        status: 'partial',
      );
      // A payment that is NOT reflected in the record's stored balance must
      // not change outstanding — stored balances are the single source.
      await insertPayment(
        studentId: studentId,
        feeRecordId: feeId,
        amount: 3000,
        date: '2026-08-10',
        id: 'PAY-000001',
      );

      final summary = await repository.load(now: now);
      expect(summary.outstandingFees, 3000);
    });
  });

  group('salaries and expenses', () {
    test(
      'current month salary counts paid records by payment_date only',
      () async {
        await openDb();
        final paidAug = await insertEmployee(id: 'EMP-000001');
        final paidJulPeriod = await insertEmployee(id: 'EMP-000002');
        final pendingAug = await insertEmployee(id: 'EMP-000003');
        final paidJuly = await insertEmployee(id: 'EMP-000004');

        await insertSalary(
          employeeId: paidAug,
          net: 20000,
          date: '2026-08-10',
        );
        await insertSalary(
          employeeId: paidJulPeriod,
          net: 15000,
          date: '2026-08-05',
          periodStart: '2026-07-01',
        );
        await insertSalary(
          employeeId: pendingAug,
          net: 40000,
          date: '2026-08-12',
          status: 'pending',
        );
        await insertSalary(
          employeeId: paidJuly,
          net: 30000,
          date: '2026-07-28',
          periodStart: '2026-07-01',
        );

        final summary = await repository.load(now: now);
        expect(summary.monthSalary, 35000);
      },
    );

    test('current month pending salaries count by period_start only', () async {
      await openDb();
      final e1 = await insertEmployee(id: 'EMP-000001');
      final e2 = await insertEmployee(id: 'EMP-000002');
      final e3 = await insertEmployee(id: 'EMP-000003');

      await insertSalary(
        employeeId: e1,
        net: 30000,
        date: '2026-08-20',
        status: 'pending',
      );
      await insertSalary(
        employeeId: e2,
        net: 15000,
        date: '2026-08-05',
        status: 'pending',
      );
      await insertSalary(
        employeeId: e3,
        net: 40000,
        date: '2026-08-12',
        status: 'paid',
      );
      // A pending record for a different month must not count.
      await database!.raw.insert('salary_records', {
        'employee_id': e3,
        'period_start': '2026-07-01',
        'period_end': '2026-07-31',
        'base_salary': 25000,
        'net_amount': 25000,
        'payment_date': null,
        'status': 'pending',
        'created_at': '2026-07-01T00:00:00Z',
      });

      final summary = await repository.load(now: now);
      expect(summary.monthSalary, 40000);
      expect(summary.monthPendingSalary, 45000);
    });

    test('current month expenses only', () async {
      await openDb();
      await insertExpense(amount: 1000, date: '2026-08-10', id: 'EXP-1');
      await insertExpense(amount: 2500, date: '2026-08-01', id: 'EXP-2');
      await insertExpense(amount: 9000, date: '2026-07-31', id: 'EXP-3');

      final summary = await repository.load(now: now);
      expect(summary.monthExpenses, 3500);
    });
  });

  group('recent activity', () {
    test(
      'returns recent payments, admissions and expenses in date order',
      () async {
        await openDb();
        final familyId = await insertFamily();
        final studentId = await insertStudent(
          familyId: familyId,
          name: 'Ali Raza',
        );

        await insertAdmission(
          studentId: studentId,
          date: '2026-08-12',
          id: 'ADM-1',
        );
        await insertPayment(
          studentId: studentId,
          amount: 500,
          date: '2026-08-13',
          id: 'PAY-1',
        );
        await insertExpense(amount: 1200, date: '2026-08-11', id: 'EXP-1');

        final summary = await repository.load(now: now);
        expect(summary.recentPayments.single.title, 'Ali Raza');
        expect(summary.recentPayments.single.amount, 500);
        expect(summary.recentAdmissions.single.title, 'Ali Raza');
        expect(summary.recentAdmissions.single.subtitle, contains('5'));
        expect(summary.recentExpenses.single.amount, 1200);
        expect(summary.isEmpty, isFalse);
      },
    );

    test('limits recent activity to eight rows', () async {
      await openDb();
      final familyId = await insertFamily();
      final studentId = await insertStudent(familyId: familyId);
      for (var i = 0; i < 10; i++) {
        await insertPayment(
          studentId: studentId,
          amount: 100,
          date: '2026-08-${(i + 1).toString().padLeft(2, '0')}',
          id: 'PAY-$i',
        );
      }

      final summary = await repository.load(now: now);
      expect(summary.recentPayments.length, 8);
    });
  });
}
