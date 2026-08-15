import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/core/database/app_database.dart';
import 'package:school_office_management/features/fee/data/repositories/fee_repository_impl.dart';
import 'package:school_office_management/features/fee/domain/entities/fee_period.dart';
import 'package:school_office_management/features/fee/domain/entities/fee_record.dart';
import 'package:school_office_management/features/fee/domain/entities/fee_status.dart';
import 'package:school_office_management/features/fee/domain/entities/payment_record.dart';
import 'package:school_office_management/features/fee/domain/repositories/fee_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppDatabase? database;
  late FeeRepositoryImpl repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> openDb() async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    database = db;
    repository = FeeRepositoryImpl(db.raw);
  }

  tearDown(() async {
    await database?.close();
    database = null;
  });

  const ts = '2026-08-01T00:00:00Z';

  var familySeq = 0;

  Future<int> insertFamily({
    required String name,
    String status = 'active',
  }) async {
    familySeq++;
    return database!.raw.insert('families', {
      'family_id': 'FAM-${familySeq.toString().padLeft(6, '0')}',
      'guardian_name': name,
      'status': status,
      'created_at': ts,
      'updated_at': ts,
    });
  }

  Future<int> insertStudent({
    required int familyId,
    required String id,
    required String name,
    String? className,
    String section = 'A',
    String status = 'active',
  }) async {
    return database!.raw.insert('students', {
      'student_id': id,
      'family_id': familyId,
      'name': name,
      'class': className,
      'section': section,
      'status': status,
      'created_at': ts,
      'updated_at': ts,
    });
  }

  Future<int> insertFeeRecord({
    required int studentId,
    required String feeRecordId,
    required String periodStart,
    required String periodEnd,
    required double expected,
    double discount = 0,
    double fine = 0,
    double paid = 0,
    required String status,
  }) async {
    final net = (expected - discount + fine).clamp(0.0, double.infinity);
    final remaining = (net - paid).clamp(0.0, double.infinity);
    return database!.raw.insert('fee_records', {
      'fee_record_id': feeRecordId,
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
      'created_at': ts,
      'updated_at': ts,
    });
  }

  /// Creates a family + student pair and returns both IDs.
  Future<(int, int)> familyAndStudent({
    required String familyName,
    required String studentId,
    required String studentName,
    String? className,
  }) async {
    final familyId = await insertFamily(name: familyName);
    final student = await insertStudent(
      familyId: familyId,
      id: studentId,
      name: studentName,
      className: className,
    );
    return (familyId, student);
  }

  group('fee structures', () {
    test('creates a class rule and a default rule with sequential IDs', () async {
      await openDb();
      final classRule = await repository.createFeeStructure(
        name: 'Class 5 Fee',
        className: 'Class 5',
        monthlyAmount: 5000,
        discountAmount: 500,
      );
      final defaultRule = await repository.createFeeStructure(
        name: 'Default Fee',
        monthlyAmount: 3000,
      );

      expect(classRule.structureId, 'FS-000001');
      expect(classRule.className, 'Class 5');
      expect(classRule.monthlyAmount, 5000);
      expect(classRule.discountAmount, 500);
      expect(classRule.isDefault, isFalse);

      expect(defaultRule.structureId, 'FS-000002');
      expect(defaultRule.className, isNull);
      expect(defaultRule.isDefault, isTrue);

      final all = await repository.listFeeStructures();
      expect(all, hasLength(2));
    });

    test('a second rule for the same class is rejected', () async {
      await openDb();
      await repository.createFeeStructure(
        name: 'First',
        className: 'Class 5',
        monthlyAmount: 5000,
      );
      await expectLater(
        repository.createFeeStructure(
          name: 'Second',
          className: 'Class 5',
          monthlyAmount: 4000,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a second global default rule is rejected', () async {
      await openDb();
      await repository.createFeeStructure(
        name: 'Default 1',
        monthlyAmount: 5000,
      );
      await expectLater(
        repository.createFeeStructure(
          name: 'Default 2',
          monthlyAmount: 4000,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty names and negative amounts', () async {
      await openDb();
      await expectLater(
        repository.createFeeStructure(name: '  ', monthlyAmount: 1000),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repository.createFeeStructure(name: 'X', monthlyAmount: -1),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repository.createFeeStructure(
          name: 'X',
          monthlyAmount: 1000,
          discountAmount: -5,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('toggle active and update a rule', () async {
      await openDb();
      final rule = await repository.createFeeStructure(
        name: 'Class 5 Fee',
        className: 'Class 5',
        monthlyAmount: 5000,
      );

      await repository.setFeeStructureActive(rule.id, false);
      var loaded = (await repository.listFeeStructures()).single;
      expect(loaded.isActive, isFalse);

      await repository.setFeeStructureActive(rule.id, true);
      loaded = (await repository.listFeeStructures()).single;
      expect(loaded.isActive, isTrue);

      final updated = await repository.updateFeeStructure(
        id: rule.id,
        name: 'Class 5 Fee (updated)',
        className: 'Class 5',
        monthlyAmount: 5500,
      );
      expect(updated.monthlyAmount, 5500);
      expect(updated.name, 'Class 5 Fee (updated)');
    });
  });

  group('monthly fee generation', () {
    test(
      'resolves the class rule first, the default rule second, and skips none',
      () async {
        await openDb();
        await repository.createFeeStructure(
          name: 'Class 5 Fee',
          className: 'Class 5',
          monthlyAmount: 5000,
          discountAmount: 500,
        );
        await repository.createFeeStructure(
          name: 'Default Fee',
          monthlyAmount: 3000,
        );

        final (_, ali) = await familyAndStudent(
          familyName: 'Khan',
          studentId: 'STU-1',
          studentName: 'Ali',
          className: 'Class 5',
        );
        final (_, usman) = await familyAndStudent(
          familyName: 'Khan',
          studentId: 'STU-2',
          studentName: 'Usman',
          className: 'Class 6',
        );
        final (_, fatima) = await familyAndStudent(
          familyName: 'Khan',
          studentId: 'STU-3',
          studentName: 'Fatima',
        );

        final period = const FeePeriod(year: 2026, month: 8);
        final result = await repository.generateMonthlyFees(
          year: 2026,
          month: 8,
        );

        expect(result.created, 3);
        expect(result.alreadyExists, 0);
        expect(result.noRule, 0);

        final aliRecord = (await repository.getFeeRecordForPeriod(
          ali,
          period,
        ))!;
        expect(aliRecord.expectedAmount, 5000);
        expect(aliRecord.discount, 500);
        expect(aliRecord.fine, 0);
        expect(aliRecord.netPayable, 4500);
        expect(aliRecord.paidAmount, 0);
        expect(aliRecord.remainingAmount, 4500);
        expect(aliRecord.status, FeeStatus.unpaid);
        expect(aliRecord.period, period);

        final usmanRecord = (await repository.getFeeRecordForPeriod(
          usman,
          period,
        ))!;
        expect(usmanRecord.netPayable, 3000);
        expect(usmanRecord.discount, 0);

        final fatimaRecord = (await repository.getFeeRecordForPeriod(
          fatima,
          period,
        ))!;
        expect(fatimaRecord.netPayable, 3000);
      },
    );

    test('students without any rule are reported and skipped', () async {
      await openDb();
      await repository.createFeeStructure(
        name: 'Class 5 Fee',
        className: 'Class 5',
        monthlyAmount: 5000,
      );

      final (_, withRule) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
        className: 'Class 5',
      );
      final (_, noRule) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-2',
        studentName: 'Usman',
        className: 'Class 9',
      );

      final period = const FeePeriod(year: 2026, month: 8);
      final result = await repository.generateMonthlyFees(year: 2026, month: 8);

      expect(result.created, 1);
      expect(result.noRule, 1);
      expect(await repository.getFeeRecordForPeriod(withRule, period), isNotNull);
      expect(await repository.getFeeRecordForPeriod(noRule, period), isNull);
    });

    test('only active students receive a charge', () async {
      await openDb();
      await repository.createFeeStructure(
        name: 'Default Fee',
        monthlyAmount: 4000,
      );
      await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Active',
      );
      await insertStudent(
        familyId: await insertFamily(name: 'Left'),
        id: 'STU-2',
        name: 'Left Student',
        className: 'Class 5',
        status: 'left',
      );

      final result = await repository.generateMonthlyFees(year: 2026, month: 8);
      expect(result.created, 1);

      final all = await database!.raw.query('fee_records');
      expect(all, hasLength(1));
      expect(all.single['student_id'], 1);
    });

    test('generation is idempotent for the same month', () async {
      await openDb();
      await repository.createFeeStructure(
        name: 'Default Fee',
        monthlyAmount: 4000,
      );
      await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-2',
        studentName: 'Usman',
      );

      final first = await repository.generateMonthlyFees(year: 2026, month: 8);
      expect(first.created, 2);

      final second = await repository.generateMonthlyFees(year: 2026, month: 8);
      expect(second.created, 0);
      expect(second.alreadyExists, 2);

      final rows = await database!.raw.query('fee_records');
      expect(rows, hasLength(2));
    });

    test('a different month creates fresh records', () async {
      await openDb();
      await repository.createFeeStructure(
        name: 'Default Fee',
        monthlyAmount: 4000,
      );
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );

      await repository.generateMonthlyFees(year: 2026, month: 8);
      final second = await repository.generateMonthlyFees(year: 2026, month: 9);

      expect(second.created, 1);
      final august = await repository.getFeeRecordForPeriod(
        student,
        const FeePeriod(year: 2026, month: 8),
      );
      final september = await repository.getFeeRecordForPeriod(
        student,
        const FeePeriod(year: 2026, month: 9),
      );
      expect(august, isNotNull);
      expect(september, isNotNull);
    });

    test('reports progress through the onProgress callback', () async {
      await openDb();
      await repository.createFeeStructure(
        name: 'Default Fee',
        monthlyAmount: 4000,
      );
      await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-2',
        studentName: 'Usman',
      );

      final progress = <(int, int)>[];
      await repository.generateMonthlyFees(
        year: 2026,
        month: 8,
        onProgress: (processed, total) => progress.add((processed, total)),
      );
      expect(progress, [(1, 2), (2, 2)]);
    });
  });

  group('payments', () {
    Future<FeeRecord> createCharge({
      required int studentId,
      String feeRecordId = 'FEE-PAY',
      double expected = 2000,
      double discount = 0,
      double fine = 0,
    }) async {
      final id = await insertFeeRecord(
        studentId: studentId,
        feeRecordId: feeRecordId,
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: expected,
        discount: discount,
        fine: fine,
        status: 'pending',
      );
      return (await repository.getFeeRecord(id))!;
    }

    test('a full payment marks the record paid with zero remaining', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final record = await createCharge(studentId: student, expected: 2000);

      final payment = await repository.recordPayment(
        feeRecordId: record.id,
        studentId: student,
        amount: 2000,
        paymentDate: DateTime(2026, 8, 10),
        createdByName: 'Admin',
      );

      expect(payment.paymentId, 'PAY-000001');
      expect(payment.amount, 2000);
      expect(payment.receiptNumber, 'RCP-000001');
      expect(payment.status, PaymentStatus.active);

      final loaded = (await repository.getFeeRecord(record.id))!;
      expect(loaded.paidAmount, 2000);
      expect(loaded.remainingAmount, 0);
      expect(loaded.status, FeeStatus.paid);
    });

    test('a partial payment leaves the record partially paid', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final record = await createCharge(studentId: student, expected: 2000);

      await repository.recordPayment(
        feeRecordId: record.id,
        studentId: student,
        amount: 1000,
        paymentDate: DateTime(2026, 8, 10),
      );

      final loaded = (await repository.getFeeRecord(record.id))!;
      expect(loaded.paidAmount, 1000);
      expect(loaded.remainingAmount, 1000);
      expect(loaded.status, FeeStatus.partial);
    });

    test('multiple payments accumulate until the balance reaches zero', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final record = await createCharge(studentId: student, expected: 2000);

      await repository.recordPayment(
        feeRecordId: record.id,
        studentId: student,
        amount: 700,
        paymentDate: DateTime(2026, 8, 5),
      );
      await repository.recordPayment(
        feeRecordId: record.id,
        studentId: student,
        amount: 300,
        paymentDate: DateTime(2026, 8, 12),
      );
      await repository.recordPayment(
        feeRecordId: record.id,
        studentId: student,
        amount: 1000,
        paymentDate: DateTime(2026, 8, 20),
      );

      final loaded = (await repository.getFeeRecord(record.id))!;
      expect(loaded.paidAmount, 2000);
      expect(loaded.remainingAmount, 0);
      expect(loaded.status, FeeStatus.paid);

      final details = await repository.getFeeRecordDetails(record.id);
      expect(details.payments, hasLength(3));
      expect(
        details.payments.map((p) => p.receiptNumber).toList(),
        ['RCP-000003', 'RCP-000002', 'RCP-000001'],
      );
    });

    test('overpayment is rejected and leaves the record unchanged', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final record = await createCharge(studentId: student, expected: 2000);

      await expectLater(
        repository.recordPayment(
          feeRecordId: record.id,
          studentId: student,
          amount: 2000.01,
          paymentDate: DateTime(2026, 8, 10),
        ),
        throwsA(isA<OverpaymentException>()),
      );

      final loaded = (await repository.getFeeRecord(record.id))!;
      expect(loaded.paidAmount, 0);
      expect(loaded.remainingAmount, 2000);
      expect(loaded.status, FeeStatus.unpaid);
    });

    test('paying against the wrong student is rejected', () async {
      await openDb();
      final (_, ali) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final (_, usman) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-2',
        studentName: 'Usman',
      );
      final record = await createCharge(studentId: ali, expected: 2000);

      await expectLater(
        repository.recordPayment(
          feeRecordId: record.id,
          studentId: usman,
          amount: 1000,
          paymentDate: DateTime(2026, 8, 10),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('non-positive and missing amounts are rejected', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final record = await createCharge(studentId: student, expected: 2000);

      await expectLater(
        repository.recordPayment(
          feeRecordId: record.id,
          studentId: student,
          amount: 0,
          paymentDate: DateTime(2026, 8, 10),
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repository.recordPayment(
          feeRecordId: record.id,
          studentId: student,
          amount: -5,
          paymentDate: DateTime(2026, 8, 10),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('discount and fine', () {
    test('discount reduces net payable and remaining', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final recordId = await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-ADJ',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 2000,
        status: 'pending',
      );

      final adjusted = await repository.adjustFeeRecord(
        feeRecordId: recordId,
        discount: 500,
      );

      expect(adjusted.discount, 500);
      expect(adjusted.fine, 0);
      expect(adjusted.netPayable, 1500);
      expect(adjusted.remainingAmount, 1500);
      expect(adjusted.status, FeeStatus.unpaid);
    });

    test('fine increases net payable and remaining', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final recordId = await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-ADJ',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 2000,
        status: 'pending',
      );

      final adjusted = await repository.adjustFeeRecord(
        feeRecordId: recordId,
        fine: 200,
      );

      expect(adjusted.netPayable, 2200);
      expect(adjusted.remainingAmount, 2200);
      expect(adjusted.status, FeeStatus.unpaid);
    });

    test('negative discount or fine is rejected', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final recordId = await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-ADJ',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 2000,
        status: 'pending',
      );

      await expectLater(
        repository.adjustFeeRecord(feeRecordId: recordId, discount: -1),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repository.adjustFeeRecord(feeRecordId: recordId, fine: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('paying the adjusted balance completes the record', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final recordId = await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-ADJ',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 2000,
        status: 'pending',
      );

      await repository.adjustFeeRecord(feeRecordId: recordId, discount: 500);
      await repository.adjustFeeRecord(feeRecordId: recordId, fine: 100);

      final loaded = (await repository.getFeeRecord(recordId))!;
      expect(loaded.netPayable, 1600);

      await repository.recordPayment(
        feeRecordId: recordId,
        studentId: student,
        amount: 1600,
        paymentDate: DateTime(2026, 8, 10),
      );

      final after = (await repository.getFeeRecord(recordId))!;
      expect(after.paidAmount, 1600);
      expect(after.remainingAmount, 0);
      expect(after.status, FeeStatus.paid);
    });
  });

  group('receipts', () {
    Future<int> createPaidRecord({required int studentId}) async {
      final recordId = await insertFeeRecord(
        studentId: studentId,
        feeRecordId: 'FEE-RCP-$studentId',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 2000,
        status: 'pending',
      );
      return recordId;
    }

    test('auto receipt numbers are sequential', () async {
      await openDb();
      final (_, ali) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final (_, usman) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-2',
        studentName: 'Usman',
      );
      final aliRecord = await createPaidRecord(studentId: ali);
      final usmanRecord = await createPaidRecord(studentId: usman);

      final first = await repository.recordPayment(
        feeRecordId: aliRecord,
        studentId: ali,
        amount: 1000,
        paymentDate: DateTime(2026, 8, 10),
      );
      final second = await repository.recordPayment(
        feeRecordId: usmanRecord,
        studentId: usman,
        amount: 2000,
        paymentDate: DateTime(2026, 8, 11),
      );

      expect(first.receiptNumber, 'RCP-000001');
      expect(second.receiptNumber, 'RCP-000002');
    });

    test('an operator-provided receipt number is kept as given', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final record = await createPaidRecord(studentId: student);

      final payment = await repository.recordPayment(
        feeRecordId: record,
        studentId: student,
        amount: 1000,
        paymentDate: DateTime(2026, 8, 10),
        receiptNumber: 'RCP-MANUAL-42',
      );

      expect(payment.receiptNumber, 'RCP-MANUAL-42');
    });

    test('a duplicate receipt number is rejected case-insensitively', () async {
      await openDb();
      final (_, ali) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final (_, usman) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-2',
        studentName: 'Usman',
      );
      final aliRecord = await createPaidRecord(studentId: ali);
      final usmanRecord = await createPaidRecord(studentId: usman);

      await repository.recordPayment(
        feeRecordId: aliRecord,
        studentId: ali,
        amount: 1000,
        paymentDate: DateTime(2026, 8, 10),
        receiptNumber: 'RCP-X',
      );

      await expectLater(
        repository.recordPayment(
          feeRecordId: usmanRecord,
          studentId: usman,
          amount: 1000,
          paymentDate: DateTime(2026, 8, 11),
          receiptNumber: 'rcp-x',
        ),
        throwsA(isA<DuplicateReceiptException>()),
      );
    });

    test('receipt data joins the fee record, student and family', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Ahmed Khan',
        studentId: 'STU-000001',
        studentName: 'Ali Khan',
        className: 'Class 5',
      );
      final recordId = await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-RCP',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 2000,
        discount: 200,
        fine: 50,
        status: 'pending',
      );

      final payment = await repository.recordPayment(
        feeRecordId: recordId,
        studentId: student,
        amount: 1850,
        paymentDate: DateTime(2026, 8, 10),
        note: 'August fee',
        createdByName: 'Admin User',
      );

      final receipt = (await repository.receiptData(payment.id))!;
      expect(receipt.paymentId, 'PAY-000001');
      expect(receipt.receiptNumber, 'RCP-000001');
      expect(receipt.studentId, 'STU-000001');
      expect(receipt.studentName, 'Ali Khan');
      expect(receipt.guardianName, 'Ahmed Khan');
      expect(receipt.periodLabel, 'Aug 2026');
      expect(receipt.expectedAmount, 2000);
      expect(receipt.discount, 200);
      expect(receipt.fine, 50);
      expect(receipt.netPayable, 1850);
      expect(receipt.paidAmount, 1850);
      expect(receipt.remainingAmount, 0);
      expect(receipt.paymentDate, DateTime(2026, 8, 10));
      expect(receipt.paymentNote, 'August fee');
      expect(receipt.createdByName, 'Admin User');
      expect(receipt.isReversed, isFalse);
    });

    test('a reversed payment produces a flagged receipt', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final record = await createPaidRecord(studentId: student);
      final payment = await repository.recordPayment(
        feeRecordId: record,
        studentId: student,
        amount: 1000,
        paymentDate: DateTime(2026, 8, 10),
      );

      await repository.reversePayment(
        paymentId: payment.id,
        byName: 'Admin',
        reason: 'Wrong amount',
      );

      final receipt = (await repository.receiptData(payment.id))!;
      expect(receipt.isReversed, isTrue);
    });
  });

  group('reversal and data safety', () {
    test('reversal restores balance and flags, never deletes', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final recordId = await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-REV',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 2000,
        status: 'pending',
      );

      await repository.recordPayment(
        feeRecordId: recordId,
        studentId: student,
        amount: 1000,
        paymentDate: DateTime(2026, 8, 10),
      );
      final payment = await repository.recordPayment(
        feeRecordId: recordId,
        studentId: student,
        amount: 1000,
        paymentDate: DateTime(2026, 8, 11),
      );

      final reversed = await repository.reversePayment(
        paymentId: payment.id,
        byName: 'Admin',
        reason: 'Duplicate entry',
      );

      expect(reversed.status, PaymentStatus.reversed);
      expect(reversed.reverseReason, 'Duplicate entry');
      expect(reversed.reversedByName, 'Admin');
      expect(reversed.reversedAt, isNotNull);

      final details = await repository.getFeeRecordDetails(recordId);
      expect(details.payments, hasLength(2));
      expect(
        details.payments.where((p) => p.status == PaymentStatus.active),
        hasLength(1),
      );

      final loaded = (await repository.getFeeRecord(recordId))!;
      expect(loaded.paidAmount, 1000);
      expect(loaded.remainingAmount, 1000);
      expect(loaded.status, FeeStatus.partial);
    });

    test('reversing the only payment returns the record to unpaid', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final recordId = await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-REV',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 2000,
        status: 'pending',
      );
      final payment = await repository.recordPayment(
        feeRecordId: recordId,
        studentId: student,
        amount: 2000,
        paymentDate: DateTime(2026, 8, 10),
      );

      await repository.reversePayment(
        paymentId: payment.id,
        reason: 'Cancelled',
      );

      final loaded = (await repository.getFeeRecord(recordId))!;
      expect(loaded.paidAmount, 0);
      expect(loaded.remainingAmount, 2000);
      expect(loaded.status, FeeStatus.unpaid);
    });

    test('reversing an already-reversed payment is rejected', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final recordId = await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-REV',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 2000,
        status: 'pending',
      );
      final payment = await repository.recordPayment(
        feeRecordId: recordId,
        studentId: student,
        amount: 1000,
        paymentDate: DateTime(2026, 8, 10),
      );
      await repository.reversePayment(paymentId: payment.id, reason: 'First');

      await expectLater(
        repository.reversePayment(paymentId: payment.id, reason: 'Second'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('reports', () {
    test('total outstanding sums only pending and partial records', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-1',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 5000,
        paid: 1000,
        status: 'pending',
      );
      await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-2',
        periodStart: '2026-09-01',
        periodEnd: '2026-09-30',
        expected: 3000,
        status: 'partial',
      );
      await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-3',
        periodStart: '2026-10-01',
        periodEnd: '2026-10-31',
        expected: 5000,
        status: 'paid',
      );
      await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-4',
        periodStart: '2026-11-01',
        periodEnd: '2026-11-30',
        expected: 9999,
        status: 'cancelled',
      );

      expect(await repository.totalOutstanding(), 7000);
    });

    test('unpaid students lists unpaid and partial for the period only', () async {
      await openDb();
      final (_, ali) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali Khan',
        className: 'Class 5',
      );
      final (_, usman) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-2',
        studentName: 'Usman Khan',
      );
      final (_, paid) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-3',
        studentName: 'Paid Student',
      );

      await insertFeeRecord(
        studentId: ali,
        feeRecordId: 'FEE-1',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 5000,
        status: 'pending',
      );
      await insertFeeRecord(
        studentId: usman,
        feeRecordId: 'FEE-2',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 3000,
        paid: 1000,
        status: 'partial',
      );
      await insertFeeRecord(
        studentId: paid,
        feeRecordId: 'FEE-3',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 3000,
        paid: 3000,
        status: 'paid',
      );
      await insertFeeRecord(
        studentId: usman,
        feeRecordId: 'FEE-4',
        periodStart: '2026-09-01',
        periodEnd: '2026-09-30',
        expected: 3000,
        status: 'pending',
      );

      final rows = await repository.unpaidStudents(
        const FeePeriod(year: 2026, month: 8),
      );

      expect(rows, hasLength(2));
      expect(rows.map((r) => r.studentName).toList(), [
        'Ali Khan',
        'Usman Khan',
      ]);
      final aliRow = rows.first;
      expect(aliRow.studentId, 'STU-1');
      expect(aliRow.guardianName, 'Khan');
      expect(aliRow.className, 'Class 5');
      expect(aliRow.record.remainingAmount, 5000);
      expect(aliRow.record.status, FeeStatus.unpaid);
      expect(rows[1].record.remainingAmount, 2000);
      expect(rows[1].record.status, FeeStatus.partial);
    });

    test('monthly collection counts active payments by their date', () async {
      await openDb();
      final (_, ali) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final (_, usman) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-2',
        studentName: 'Usman',
      );
      final aliRecord = await insertFeeRecord(
        studentId: ali,
        feeRecordId: 'FEE-1',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 5000,
        status: 'pending',
      );
      final usmanRecord = await insertFeeRecord(
        studentId: usman,
        feeRecordId: 'FEE-2',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 3000,
        status: 'pending',
      );

      final augustPayment = await repository.recordPayment(
        feeRecordId: aliRecord,
        studentId: ali,
        amount: 2000,
        paymentDate: DateTime(2026, 8, 10),
      );
      await repository.recordPayment(
        feeRecordId: usmanRecord,
        studentId: usman,
        amount: 3000,
        paymentDate: DateTime(2026, 8, 31),
      );
      // A payment in September must not count towards August.
      final septemberRecord = await insertFeeRecord(
        studentId: ali,
        feeRecordId: 'FEE-3',
        periodStart: '2026-09-01',
        periodEnd: '2026-09-30',
        expected: 5000,
        status: 'pending',
      );
      await repository.recordPayment(
        feeRecordId: septemberRecord,
        studentId: ali,
        amount: 2500,
        paymentDate: DateTime(2026, 9, 1),
      );
      await repository.reversePayment(paymentId: augustPayment.id);

      final august = await repository.monthlyCollection(year: 2026, month: 8);
      expect(august.collected, 3000);
      expect(august.paymentCount, 1);

      final september = await repository.monthlyCollection(
        year: 2026,
        month: 9,
      );
      expect(september.collected, 2500);
      expect(september.paymentCount, 1);
    });

    test('family outstanding aggregates families without leaking', () async {
      await openDb();
      final familyA = await insertFamily(name: 'Khan');
      final ali = await insertStudent(
        familyId: familyA,
        id: 'STU-1',
        name: 'Ali',
      );
      final usman = await insertStudent(
        familyId: familyA,
        id: 'STU-2',
        name: 'Usman',
      );
      final familyB = await insertFamily(name: 'Other');
      final sara = await insertStudent(
        familyId: familyB,
        id: 'STU-3',
        name: 'Sara',
      );
      final familyC = await insertFamily(name: 'Clear');
      final none = await insertStudent(
        familyId: familyC,
        id: 'STU-4',
        name: 'No Balance',
      );
      await insertFamily(name: 'Empty Family');

      await insertFeeRecord(
        studentId: ali,
        feeRecordId: 'FEE-1',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 5000,
        paid: 1000,
        status: 'pending',
      );
      await insertFeeRecord(
        studentId: usman,
        feeRecordId: 'FEE-2',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 3000,
        status: 'partial',
      );
      await insertFeeRecord(
        studentId: sara,
        feeRecordId: 'FEE-3',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 8000,
        status: 'pending',
      );
      await insertFeeRecord(
        studentId: none,
        feeRecordId: 'FEE-4',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 5000,
        paid: 5000,
        status: 'paid',
      );

      final rows = await repository.familyOutstanding();

      expect(rows, hasLength(2));
      expect(rows.map((r) => r.familyId).toSet(), {familyA, familyB});
      final a = rows.firstWhere((r) => r.familyId == familyA);
      expect(a.guardianName, 'Khan');
      expect(a.studentCount, 2);
      expect(a.outstanding, 7000);
      final b = rows.firstWhere((r) => r.familyId == familyB);
      expect(b.outstanding, 8000);
    });
  });

  group('search', () {
    test('searches by student name, family and student ID', () async {
      await openDb();
      final (_, ali) = await familyAndStudent(
        familyName: 'Ahmed Khan',
        studentId: 'STU-000001',
        studentName: 'Ali Khan',
        className: 'Class 5',
      );
      final (_, usman) = await familyAndStudent(
        familyName: 'Sara Khan',
        studentId: 'STU-000002',
        studentName: 'Usman Khan',
      );
      await insertFeeRecord(
        studentId: ali,
        feeRecordId: 'FEE-1',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 5000,
        status: 'pending',
      );
      await insertFeeRecord(
        studentId: usman,
        feeRecordId: 'FEE-2',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 3000,
        status: 'pending',
      );

      expect((await repository.searchFeeRecords(query: 'ali')).length, 1);
      expect((await repository.searchFeeRecords(query: 'Ahmed')).length, 1);
      expect(
        (await repository.searchFeeRecords(query: 'STU-000002')).single
            .studentName,
        'Usman Khan',
      );
      expect(await repository.searchFeeRecords(query: 'khan'), hasLength(2));
    });

    test('filters by class, period and status', () async {
      await openDb();
      final (_, ali) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
        className: 'Class 5',
      );
      final (_, usman) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-2',
        studentName: 'Usman',
        className: 'Class 6',
      );
      await insertFeeRecord(
        studentId: ali,
        feeRecordId: 'FEE-1',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 5000,
        status: 'pending',
      );
      await insertFeeRecord(
        studentId: usman,
        feeRecordId: 'FEE-2',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 3000,
        paid: 3000,
        status: 'paid',
      );

      expect(
        (await repository.searchFeeRecords(className: 'Class 5')).length,
        1,
      );
      expect(
        (
          await repository.searchFeeRecords(
            period: const FeePeriod(year: 2026, month: 8),
          )
        ).length,
        2,
      );
      expect(
        (await repository.searchFeeRecords(status: FeeStatus.paid)).single
            .studentName,
        'Usman',
      );
      expect(
        (await repository.searchFeeRecords(status: FeeStatus.unpaid)).single
            .studentName,
        'Ali',
      );
    });

    test('filters by a specific student and finds records by student ID', () async {
      await openDb();
      final (_, ali) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final (_, usman) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-2',
        studentName: 'Usman',
      );
      await insertFeeRecord(
        studentId: ali,
        feeRecordId: 'FEE-1',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 5000,
        status: 'pending',
      );
      await insertFeeRecord(
        studentId: usman,
        feeRecordId: 'FEE-2',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 3000,
        status: 'pending',
      );

      final byStudent = await repository.searchFeeRecords(studentId: ali);
      expect(byStudent.single.studentName, 'Ali');
    });

    test('student fee history is returned newest period first', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-1',
        periodStart: '2026-01-01',
        periodEnd: '2026-01-31',
        expected: 5000,
        status: 'pending',
      );
      await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-2',
        periodStart: '2026-12-01',
        periodEnd: '2026-12-31',
        expected: 5000,
        status: 'paid',
      );
      await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-3',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 5000,
        status: 'partial',
      );

      final history = await repository.studentFeeHistory(student);
      expect(
        history.map((r) => r.period.startIso).toList(),
        ['2026-12-01', '2026-08-01', '2026-01-01'],
      );
      expect(history.first.status, FeeStatus.paid);
      expect(history.last.status, FeeStatus.unpaid);
    });

    test('search students finds active students for payment collection', () async {
      await openDb();
      await familyAndStudent(
        familyName: 'Ahmed Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      await insertStudent(
        familyId: await insertFamily(name: 'Left'),
        id: 'STU-2',
        name: 'Gone',
        status: 'left',
      );

      final picks = await repository.searchStudents('ali');
      expect(picks.single.studentId, 'STU-1');
      expect(picks.single.guardianName, 'Ahmed Khan');

      expect(await repository.searchStudents('gone'), isEmpty);
    });
  });

  group('month and date boundaries', () {
    test('periods wrap correctly across January and December', () {
      final jan = const FeePeriod(year: 2026, month: 1);
      expect(jan.startIso, '2026-01-01');
      expect(jan.endIso, '2026-01-31');
      expect(jan.monthKey, '2026-01');

      final dec = const FeePeriod(year: 2026, month: 12);
      expect(dec.startIso, '2026-12-01');
      expect(dec.endIso, '2026-12-31');
      expect(dec.monthKey, '2026-12');
    });

    test('leap-year February has 29 days, regular February has 28', () {
      expect(
        const FeePeriod(year: 2028, month: 2).endIso,
        '2028-02-29',
      );
      expect(
        const FeePeriod(year: 2026, month: 2).endIso,
        '2026-02-28',
      );
    });

    test('previous and next cross the year boundary', () {
      expect(
        FeePeriod.previous(const FeePeriod(year: 2026, month: 1)),
        const FeePeriod(year: 2025, month: 12),
      );
      expect(
        FeePeriod.next(const FeePeriod(year: 2026, month: 12)),
        const FeePeriod(year: 2027, month: 1),
      );
    });

    test('period parsing round-trips from a stored period_start', () {
      expect(FeePeriod.parse('2026-08-01'), const FeePeriod(year: 2026, month: 8));
      expect(FeePeriod.parse('2026-12-31'), const FeePeriod(year: 2026, month: 12));
    });

    test('collection counts the last day of the month but not the first of the next', () async {
      await openDb();
      final (_, student) = await familyAndStudent(
        familyName: 'Khan',
        studentId: 'STU-1',
        studentName: 'Ali',
      );
      final recordId = await insertFeeRecord(
        studentId: student,
        feeRecordId: 'FEE-1',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
        expected: 2000,
        status: 'pending',
      );

      await repository.recordPayment(
        feeRecordId: recordId,
        studentId: student,
        amount: 1000,
        paymentDate: DateTime(2026, 8, 31),
      );
      await repository.recordPayment(
        feeRecordId: recordId,
        studentId: student,
        amount: 1000,
        paymentDate: DateTime(2026, 9, 1),
      );

      final august = await repository.monthlyCollection(year: 2026, month: 8);
      expect(august.collected, 1000);
      expect(august.paymentCount, 1);

      final september = await repository.monthlyCollection(year: 2026, month: 9);
      expect(september.collected, 1000);
      expect(september.paymentCount, 1);
    });
  });
}
