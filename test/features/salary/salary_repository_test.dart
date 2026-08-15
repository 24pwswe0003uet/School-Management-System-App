import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/core/database/app_database.dart';
import 'package:school_office_management/features/salary/data/repositories/salary_repository_impl.dart';
import 'package:school_office_management/features/salary/domain/entities/salary_period.dart';
import 'package:school_office_management/features/salary/domain/entities/salary_record.dart';
import 'package:school_office_management/features/salary/domain/entities/salary_status.dart';
import 'package:school_office_management/features/salary/domain/repositories/salary_period_exists_exception.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppDatabase? database;
  late SalaryRepositoryImpl repository;

  const ts = '2026-08-01T00:00:00Z';
  final aug = SalaryPeriod(year: 2026, month: 8);
  final sep = SalaryPeriod(year: 2026, month: 9);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  var employeeSeq = 0;

  Future<void> openDb() async {
    employeeSeq = 0;
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    database = db;
    repository = SalaryRepositoryImpl(db.raw);
  }

  tearDown(() async {
    await database?.close();
    database = null;
  });

  Future<int> insertEmployee({
    String? name,
    String? designation,
    double basicSalary = 0,
    String status = 'active',
  }) async {
    employeeSeq++;
    return database!.raw.insert('employees', {
      'employee_id': 'EMP-${employeeSeq.toString().padLeft(6, '0')}',
      'name': name ?? 'Teacher $employeeSeq',
      'designation': designation,
      'basic_salary': basicSalary,
      'status': status,
      'created_at': ts,
      'updated_at': ts,
    });
  }

  Future<SalaryRecord> createDefault({
    required int employeeId,
    SalaryPeriod? period,
    double base = 30000,
    double advance = 0,
    double deduction = 0,
    double adjustment = 0,
    SalaryStatus status = SalaryStatus.pending,
    DateTime? paymentDate,
  }) {
    return repository.createSalary(
      employeeId: employeeId,
      period: period ?? aug,
      baseSalary: base,
      advance: advance,
      deduction: deduction,
      otherAdjustment: adjustment,
      status: status,
      paymentDate: paymentDate,
    );
  }

  void closeTo(double a, double b) =>
      expect((a - b).abs(), lessThan(0.0001));

  group('createSalary', () {
    test('auto-assigns codes, stores components and derives net', () async {
      await openDb();
      final employeeId = await insertEmployee(
        name: 'Ahmed Khan',
        basicSalary: 30000,
      );

      final record = await createDefault(
        employeeId: employeeId,
        base: 30000,
        advance: 2000,
        deduction: 500,
        adjustment: 250,
        status: SalaryStatus.pending,
      );

      expect(record.salaryRecordId, 'SAL-000001');
      expect(record.employeeId, employeeId);
      expect(record.period, aug);
      expect(record.status, SalaryStatus.pending);
      expect(record.paymentDate, isNull);
      closeTo(record.baseSalary, 30000);
      closeTo(record.advance, 2000);
      closeTo(record.deduction, 500);
      closeTo(record.otherAdjustment, 250);
      closeTo(record.netAmount, 27750);

      final second = await createDefault(
        employeeId: employeeId,
        period: sep,
      );
      expect(second.salaryRecordId, 'SAL-000002');
    });

    test('paid record stores the payment date', () async {
      await openDb();
      final employeeId = await insertEmployee();
      final record = await createDefault(
        employeeId: employeeId,
        status: SalaryStatus.paid,
        paymentDate: DateTime(2026, 8, 31),
      );
      expect(record.isPaid, isTrue);
      expect(record.paymentDate, DateTime(2026, 8, 31));
    });

    test('paid record without a payment date is rejected', () async {
      await openDb();
      final employeeId = await insertEmployee();
      expect(
        () => createDefault(employeeId: employeeId, status: SalaryStatus.paid),
        throwsArgumentError,
      );
    });

    test('clamps a negative net to zero', () async {
      await openDb();
      final employeeId = await insertEmployee();
      final record = await createDefault(
        employeeId: employeeId,
        base: 10000,
        advance: 12000,
        deduction: 0,
        adjustment: 0,
      );
      expect(record.netAmount, 0);
    });

    test('rejects negative components', () async {
      await openDb();
      final employeeId = await insertEmployee();
      expect(
        () => createDefault(employeeId: employeeId, base: -1),
        throwsArgumentError,
      );
      expect(
        () => createDefault(employeeId: employeeId, advance: -1),
        throwsArgumentError,
      );
      expect(
        () => createDefault(employeeId: employeeId, deduction: -1),
        throwsArgumentError,
      );
    });

    test('rejects a record for a nonexistent employee', () async {
      await openDb();
      expect(
        () => createDefault(employeeId: 999),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('one record per employee and month throws SalaryPeriodExistsException',
        () async {
      await openDb();
      final employeeId = await insertEmployee(name: 'Ahmed Khan');
      await createDefault(employeeId: employeeId, period: aug);

      expect(
        () => createDefault(employeeId: employeeId, period: aug),
        throwsA(isA<SalaryPeriodExistsException>()),
      );

      // A different month for the same employee is fine.
      final other = await createDefault(employeeId: employeeId, period: sep);
      expect(other.period, sep);
    });

    test('same month is fine for a different employee', () async {
      await openDb();
      final first = await insertEmployee();
      final second = await insertEmployee();
      await createDefault(employeeId: first, period: aug);
      final record = await createDefault(employeeId: second, period: aug);
      expect(record.employeeId, second);
    });
  });

  group('getSalaryForPeriod and history', () {
    test('returns null when no record exists for the employee and month',
        () async {
      await openDb();
      final employeeId = await insertEmployee();
      expect(
        await repository.getSalaryForPeriod(employeeId, aug),
        isNull,
      );
    });

    test('returns the matching record', () async {
      await openDb();
      final employeeId = await insertEmployee();
      await createDefault(employeeId: employeeId, period: aug);
      final found = await repository.getSalaryForPeriod(employeeId, aug);
      expect(found, isNotNull);
      expect(found!.period, aug);
    });

    test('history is ordered newest first', () async {
      await openDb();
      final employeeId = await insertEmployee();
      await createDefault(employeeId: employeeId, period: aug);
      await createDefault(employeeId: employeeId, period: sep);
      final history = await repository.salaryHistoryForEmployee(employeeId);
      expect(history.map((r) => r.period).toList(), [sep, aug]);
    });
  });

  group('searchSalaries', () {
    Future<int> seed() async {
      final ahmed = await insertEmployee(name: 'Ahmed Khan');
      final hina = await insertEmployee(name: 'Hina');
      await createDefault(
        employeeId: ahmed,
        period: aug,
        base: 30000,
        status: SalaryStatus.paid,
        paymentDate: DateTime(2026, 8, 20),
      );
      await createDefault(
        employeeId: ahmed,
        period: sep,
        base: 30000,
        status: SalaryStatus.pending,
      );
      await createDefault(
        employeeId: hina,
        period: aug,
        base: 25000,
        status: SalaryStatus.pending,
      );
      return ahmed;
    }

    test('returns records joined with employee identity', () async {
      await openDb();
      await seed();
      final results = await repository.searchSalaries();
      expect(results.length, 3);
      expect(results.first.employeeName, 'Ahmed Khan');
      expect(results.first.employeeCode, 'EMP-000001');
      expect(results.first.record.salaryRecordId, 'SAL-000002');
      expect(results.first.record.period, sep);
      expect(results.last.employeeName, 'Hina');
      expect(results.last.employeeCode, 'EMP-000002');
      expect(results.last.record.salaryRecordId, 'SAL-000003');
    });

    test('filters by employee id, month, status and year', () async {
      await openDb();
      final ahmed = await seed();

      final byEmployee = await repository.searchSalaries(employeeId: ahmed);
      expect(byEmployee.length, 2);

      final byPeriod = await repository.searchSalaries(period: aug);
      expect(byPeriod.length, 2);

      final byStatus = await repository.searchSalaries(
        status: SalaryStatus.paid,
      );
      expect(byStatus.length, 1);
      expect(byStatus.single.employeeName, 'Ahmed Khan');

      final byYear = await repository.searchSalaries(year: 2026);
      expect(byYear.length, 3);

      final emptyYear = await repository.searchSalaries(year: 2025);
      expect(emptyYear, isEmpty);
    });

    test('filters compose together', () async {
      await openDb();
      await seed();
      final results = await repository.searchSalaries(
        query: 'Ahmed',
        period: aug,
        status: SalaryStatus.paid,
        year: 2026,
      );
      expect(results.length, 1);
      expect(results.single.record.salaryRecordId, 'SAL-000001');
    });

    test('searches by employee code or name', () async {
      await openDb();
      await seed();
      expect((await repository.searchSalaries(query: 'EMP-000002')).length, 1);
      expect((await repository.searchSalaries(query: 'hina')).length, 1);
      expect((await repository.searchSalaries(query: 'zzz')), isEmpty);
    });
  });

  group('monthlyTotals', () {
    test('aggregates base, advance, deduction, adjustment and net', () async {
      await openDb();
      final first = await insertEmployee();
      final second = await insertEmployee();
      await createDefault(
        employeeId: first,
        period: aug,
        base: 30000,
        advance: 1000,
        deduction: 500,
        adjustment: 200,
        status: SalaryStatus.paid,
        paymentDate: DateTime(2026, 8, 10),
      );
      await createDefault(
        employeeId: second,
        period: aug,
        base: 20000,
        status: SalaryStatus.pending,
      );
      await createDefault(employeeId: first, period: sep);

      final totals = await repository.monthlyTotals(year: 2026, month: 8);
      expect(totals.period, aug);
      expect(totals.recordCount, 2);
      closeTo(totals.totalBase, 50000);
      closeTo(totals.totalAdvance, 1000);
      closeTo(totals.totalDeduction, 500);
      closeTo(totals.totalAdjustment, 200);
      closeTo(totals.netPayable, 28700 + 20000);
      closeTo(totals.totalPaid, 28700);
      closeTo(totals.totalPending, 20000);
    });

    test('returns zeroed totals for an empty month', () async {
      await openDb();
      final totals = await repository.monthlyTotals(year: 2026, month: 8);
      expect(totals.recordCount, 0);
      expect(totals.netPayable, 0);
      expect(totals.totalPaid, 0);
      expect(totals.totalPending, 0);
    });
  });

  group('searchEmployees', () {
    test('finds active staff by code or name with basic salary', () async {
      await openDb();
      await insertEmployee(name: 'Ahmed Khan', basicSalary: 30000);
      await insertEmployee(name: 'Hina', basicSalary: 25000, status: 'inactive');

      final matches = await repository.searchEmployees('Ahmed');
      expect(matches.length, 1);
      expect(matches.single.name, 'Ahmed Khan');
      expect(matches.single.employeeCode, 'EMP-000001');
      closeTo(matches.single.basicSalary, 30000);

      // Inactive staff never appear in the picker.
      expect(await repository.searchEmployees('Hina'), isEmpty);
      expect(await repository.searchEmployees('EMP-000001'), isNotEmpty);
      expect(await repository.searchEmployees(''), isEmpty);
    });
  });

  group('distinctYears', () {
    test('lists years with records, newest first', () async {
      await openDb();
      final employeeId = await insertEmployee();
      await createDefault(employeeId: employeeId, period: aug);
      await createDefault(
        employeeId: employeeId,
        period: SalaryPeriod(year: 2025, month: 6),
      );
      final years = await repository.distinctYears();
      expect(years, [2026, 2025]);
    });
  });

  group('updateSalary, markPaid and delete', () {
    test('updateSalary recomputes net, preserves createdAt', () async {
      await openDb();
      final employeeId = await insertEmployee();
      final created = await createDefault(
        employeeId: employeeId,
        base: 30000,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final updated = await repository.updateSalary(
        id: created.id,
        baseSalary: 35000,
        advance: 1000,
        deduction: 0,
        otherAdjustment: 0,
        status: SalaryStatus.pending,
        notes: 'revised',
      );
      closeTo(updated.netAmount, 34000);
      expect(updated.createdAt, created.createdAt);
      expect(updated.notes, 'revised');
      expect(updated.updatedAt.isAfter(created.updatedAt), isTrue);
    });

    test('markPaid sets status and date without changing amounts', () async {
      await openDb();
      final employeeId = await insertEmployee();
      final created = await createDefault(
        employeeId: employeeId,
        base: 30000,
        advance: 2000,
      );
      final paid = await repository.markPaid(
        id: created.id,
        paymentDate: DateTime(2026, 8, 25),
      );
      expect(paid.isPaid, isTrue);
      expect(paid.paymentDate, DateTime(2026, 8, 25));
      closeTo(paid.netAmount, 28000);
      closeTo(paid.baseSalary, 30000);
    });

    test('deleteSalary removes the record', () async {
      await openDb();
      final employeeId = await insertEmployee();
      final record = await createDefault(employeeId: employeeId);
      await repository.deleteSalary(record.id);
      expect(await repository.getSalaryRecord(record.id), isNull);
    });
  });

  group('history integrity', () {
    test('changing employee basic salary does not alter past records',
        () async {
      await openDb();
      final employeeId = await insertEmployee(name: 'Ahmed', basicSalary: 30000);
      final record = await createDefault(employeeId: employeeId, base: 30000);

      await database!.raw.update(
        'employees',
        {'basic_salary': 40000},
        where: 'id = ?',
        whereArgs: [employeeId],
      );

      final reloaded = await repository.getSalaryRecord(record.id);
      closeTo(reloaded!.baseSalary, 30000);
      closeTo(reloaded.netAmount, 30000);
    });
  });

  group('getSalaryRecordDetails', () {
    test('returns the record with employee display fields', () async {
      await openDb();
      final employeeId = await insertEmployee(
        name: 'Ahmed Khan',
        designation: 'Mathematics Teacher',
      );
      final record = await createDefault(employeeId: employeeId);

      final details = await repository.getSalaryRecordDetails(record.id);
      expect(details, isNotNull);
      expect(details!.employeeName, 'Ahmed Khan');
      expect(details.employeeCode, 'EMP-000001');
      expect(details.designation, 'Mathematics Teacher');
      expect(details.record.salaryRecordId, 'SAL-000001');

      expect(await repository.getSalaryRecordDetails(999), isNull);
    });
  });

  group('unique index backstop', () {
    test('the database rejects a second row for the same employee and month',
        () async {
      await openDb();
      final employeeId = await insertEmployee();
      await createDefault(employeeId: employeeId, period: aug);
      expect(
        () => database!.raw.insert('salary_records', {
          'salary_record_id': 'SAL-999999',
          'employee_id': employeeId,
          'period_start': aug.startIso,
          'period_end': aug.endIso,
          'base_salary': 100,
          'advance': 0,
          'deduction': 0,
          'other_adjustment': 0,
          'net_amount': 100,
          'status': 'pending',
          'created_at': ts,
          'updated_at': ts,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
