import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/core/database/app_database.dart';
import 'package:school_office_management/features/family/data/repositories/family_repository_impl.dart';
import 'package:school_office_management/features/family/domain/entities/family.dart';
import 'package:school_office_management/features/student/data/repositories/student_repository_impl.dart';
import 'package:school_office_management/features/student/domain/entities/student.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppDatabase? database;
  late FamilyRepositoryImpl familyRepository;
  late StudentRepositoryImpl repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> openDb() async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    database = db;
    familyRepository = FamilyRepositoryImpl(db.raw);
    repository = StudentRepositoryImpl(db.raw);
  }

  tearDown(() async {
    await database?.close();
    database = null;
  });

  const ts = '2026-08-01T00:00:00Z';

  Future<Family> createFamily({String? phone = '0300-1234567'}) {
    return familyRepository.createFamily(
      guardianName: 'Ahmed Khan',
      primaryPhone: phone,
    );
  }

  Future<int> insertFeeRecord({
    required int studentId,
    String id = 'FEE-000001',
    double expected = 5000,
    double paid = 0,
    String status = 'pending',
    String periodStart = '2026-07-01',
    String periodEnd = '2026-07-31',
  }) async {
    final remaining = (expected - paid).clamp(0, expected).toDouble();
    return database!.raw.insert('fee_records', {
      'fee_record_id': id,
      'student_id': studentId,
      'period_start': periodStart,
      'period_end': periodEnd,
      'expected_amount': expected,
      'discount': 0,
      'fine': 0,
      'net_payable': expected,
      'paid_amount': paid,
      'remaining_amount': remaining,
      'status': status,
      'created_at': ts,
      'updated_at': ts,
    });
  }

  Future<void> insertPayment({
    required int studentId,
    required int feeRecordId,
    double amount = 0,
  }) async {
    await database!.raw.insert('payments', {
      'payment_id': 'PAY-$studentId-$feeRecordId',
      'student_id': studentId,
      'fee_record_id': feeRecordId,
      'amount': amount,
      'payment_date': '2026-07-10',
      'created_at': ts,
    });
  }

  group('create student', () {
    test(
      'creates a student with a generated ID and an admission record',
      () async {
        await openDb();
        final family = await createFamily();
        final student = await repository.createStudent(
          familyId: family.id,
          name: '  Ali Khan  ',
          gender: StudentGender.male,
          dateOfBirth: DateTime(2014, 5, 1),
          admissionNumber: 'ADM-2024-100',
          admissionDate: DateTime(2024, 3, 1),
          className: '5',
          section: 'A',
        );

        expect(student.studentId, 'STU-000001');
        expect(student.name, 'Ali Khan');
        expect(student.gender, StudentGender.male);
        expect(student.admissionNumber, 'ADM-2024-100');
        expect(student.status, StudentStatus.active);
        expect(student.familyId, family.id);

        final details = await repository.getStudentDetails(student.id);
        expect(details.admissions, hasLength(1));
        expect(details.admissions.single.admissionId, 'ADM-000001');
        expect(details.admissions.single.className, '5');
      },
    );

    test('second student gets the next sequential ID', () async {
      await openDb();
      final family = await createFamily();
      final first = await repository.createStudent(
        familyId: family.id,
        name: 'Ali Khan',
      );
      final second = await repository.createStudent(
        familyId: family.id,
        name: 'Sara Khan',
      );

      expect(first.studentId, 'STU-000001');
      expect(second.studentId, 'STU-000002');
    });

    test('requires a name', () async {
      await openDb();
      final family = await createFamily();
      expect(
        () => repository.createStudent(familyId: family.id, name: '   '),
        throwsArgumentError,
      );
    });

    test('rejects a student referencing a missing family', () async {
      await openDb();
      expect(
        () => repository.createStudent(familyId: 99999, name: 'Ali Khan'),
        throwsA(isA<DatabaseException>()),
      );
    });

    test(
      'rejects a duplicate admission number but allows blank ones',
      () async {
        await openDb();
        final family = await createFamily();
        await repository.createStudent(
          familyId: family.id,
          name: 'Ali Khan',
          admissionNumber: 'ADM-100',
        );
        expect(
          () => repository.createStudent(
            familyId: family.id,
            name: 'Sara Khan',
            admissionNumber: 'adm-100',
          ),
          throwsA(isA<DatabaseException>()),
        );
        // Blank/empty admission numbers are treated as "not used".
        final ok = await repository.createStudent(
          familyId: family.id,
          name: 'Usman Khan',
          admissionNumber: '',
        );
        expect(ok.admissionNumber, isNull);
      },
    );

    test(
      'records the admission number, fee and notes on the admission record',
      () async {
        await openDb();
        final family = await createFamily();
        final student = await repository.createStudent(
          familyId: family.id,
          name: 'Ali Khan',
          admissionNumber: 'ADM-2026-001',
          admissionDate: DateTime(2026, 8, 1),
          className: '5',
          section: 'A',
          notes: 'Brought fee voucher',
          admissionFee: 5000,
        );

        final details = await repository.getStudentDetails(student.id);
        final admission = details.admissions.single;
        expect(admission.admissionNumber, 'ADM-2026-001');
        expect(admission.admissionFee, 5000);
        expect(admission.notes, 'Brought fee voucher');
        expect(admission.className, '5');
        expect(admission.section, 'A');
        expect(admission.admissionDate, DateTime(2026, 8, 1));
      },
    );

    test('two students may share the same name', () async {
      await openDb();
      final family = await createFamily();
      final a = await repository.createStudent(
        familyId: family.id,
        name: 'Ali Khan',
      );
      final b = await repository.createStudent(
        familyId: family.id,
        name: 'Ali Khan',
      );

      expect(a.studentId, 'STU-000001');
      expect(b.studentId, 'STU-000002');
    });

    test('multiple students can link to the same family', () async {
      await openDb();
      final family = await createFamily();
      final a = await repository.createStudent(
        familyId: family.id,
        name: 'Ali Khan',
      );
      final b = await repository.createStudent(
        familyId: family.id,
        name: 'Sara Khan',
      );
      final c = await repository.createStudent(
        familyId: family.id,
        name: 'Usman Khan',
      );

      expect(a.familyId, family.id);
      expect(b.familyId, family.id);
      expect(c.familyId, family.id);
      final details = await familyRepository.getFamilyDetails(family.id);
      expect(details.studentCount, 3);
    });
  });

  group('admission transaction', () {
    test(
      'rolls back the student insert when the admission insert fails',
      () async {
        await openDb();
        final family = await createFamily();
        await repository.createStudent(familyId: family.id, name: 'Ali Khan');

        // A negative fee violates the admissions.admission_fee CHECK constraint,
        // so the admission insert fails AFTER its student row was inserted in
        // the same transaction.
        expect(
          () => repository.createStudent(
            familyId: family.id,
            name: 'Sara Khan',
            admissionFee: -1,
          ),
          throwsA(isA<DatabaseException>()),
        );

        // The failed admission must not leave a half-written student behind.
        final rows = await database!.raw.query('students');
        expect(rows, hasLength(1));
        expect(rows.single['name'], 'Ali Khan');
      },
    );
  });

  group('edit and history', () {
    test('updates fields and keeps the old class in history', () async {
      await openDb();
      final family = await createFamily();
      final student = await repository.createStudent(
        familyId: family.id,
        name: 'Ali Khan',
        className: '5',
        section: 'A',
        admissionDate: DateTime(2024, 3, 1),
      );

      final updated = await repository.updateStudent(
        id: student.id,
        familyId: family.id,
        name: 'Ali Ahmed',
        gender: StudentGender.male,
        className: '6',
        section: 'B',
        admissionDate: DateTime(2024, 3, 1),
      );

      expect(updated.name, 'Ali Ahmed');
      expect(updated.className, '6');
      expect(updated.section, 'B');

      final details = await repository.getStudentDetails(student.id);
      expect(details.student.className, '6');
      expect(details.history, hasLength(1));
      expect(details.history.single.className, '6');
      expect(details.history.single.section, 'B');
      expect(details.admissions.single.className, '5');
    });

    test('edit without class/section change appends no history', () async {
      await openDb();
      final family = await createFamily();
      final student = await repository.createStudent(
        familyId: family.id,
        name: 'Ali Khan',
        className: '5',
      );

      await repository.updateStudent(
        id: student.id,
        familyId: family.id,
        name: 'Ali Khan',
        className: '5',
      );

      final details = await repository.getStudentDetails(student.id);
      expect(details.history, isEmpty);
    });

    test(
      'status change appends history and preserves the old status',
      () async {
        await openDb();
        final family = await createFamily();
        final student = await repository.createStudent(
          familyId: family.id,
          name: 'Ali Khan',
          className: '5',
        );

        final left = await repository.setStudentStatus(
          student.id,
          StudentStatus.left,
        );
        expect(left.status, StudentStatus.left);

        final transferred = await repository.setStudentStatus(
          student.id,
          StudentStatus.transferred,
        );
        expect(transferred.status, StudentStatus.transferred);

        final details = await repository.getStudentDetails(student.id);
        expect(details.history, hasLength(2));
        expect(details.history.first.status, 'transferred');
        expect(details.history.last.status, 'left');
        expect(details.history.first.className, '5');
      },
    );
  });

  group('search', () {
    test('searches by exact Student ID', () async {
      await openDb();
      final family = await createFamily();
      await repository.createStudent(familyId: family.id, name: 'Ali Khan');
      await repository.createStudent(familyId: family.id, name: 'Sara Khan');

      final results = await repository.searchStudents(query: 'STU-000002');
      expect(results, hasLength(1));
      expect(results.single.student.name, 'Sara Khan');
    });

    test('name search returns multiple students', () async {
      await openDb();
      final family = await createFamily();
      await repository.createStudent(familyId: family.id, name: 'Ali Khan');
      await repository.createStudent(familyId: family.id, name: 'Ali Khan');

      final results = await repository.searchStudents(query: 'Ali');
      expect(results, hasLength(2));
      expect(results.every((r) => r.student.name == 'Ali Khan'), isTrue);
    });

    test('searches by admission number', () async {
      await openDb();
      final family = await createFamily();
      await repository.createStudent(
        familyId: family.id,
        name: 'Ali Khan',
        admissionNumber: 'ADM-2024-100',
      );

      final results = await repository.searchStudents(query: '2024-100');
      expect(results, hasLength(1));
      expect(results.single.student.admissionNumber, 'ADM-2024-100');
    });

    test('searches by guardian name through the family', () async {
      await openDb();
      final family = await createFamily();
      await repository.createStudent(familyId: family.id, name: 'Ali Khan');

      final results = await repository.searchStudents(query: 'Ahmed');
      expect(results, hasLength(1));
      expect(results.single.guardianName, 'Ahmed Khan');
      expect(results.single.familyId, 'FAM-000001');
    });

    test('searches by phone even when typed with dashes', () async {
      await openDb();
      final family = await createFamily(phone: '0300-1234567');
      await repository.createStudent(familyId: family.id, name: 'Ali Khan');

      final results = await repository.searchStudents(query: '03001234567');
      expect(results, hasLength(1));
      final dashed = await repository.searchStudents(query: '0300-1234567');
      expect(dashed, hasLength(1));
    });

    test('searches by family ID', () async {
      await openDb();
      final family = await createFamily();
      await repository.createStudent(familyId: family.id, name: 'Ali Khan');

      final results = await repository.searchStudents(query: 'FAM-000001');
      expect(results, hasLength(1));
      expect(results.single.familyId, 'FAM-000001');
    });

    test('filters by class and by status', () async {
      await openDb();
      final family = await createFamily();
      final a = await repository.createStudent(
        familyId: family.id,
        name: 'Ali Khan',
        className: '5',
      );
      await repository.createStudent(
        familyId: family.id,
        name: 'Sara Khan',
        className: '3',
      );
      await repository.setStudentStatus(a.id, StudentStatus.left);

      final byClass = await repository.searchStudents(className: '5');
      expect(byClass, hasLength(1));
      expect(byClass.single.student.name, 'Ali Khan');

      final byStatus = await repository.searchStudents(
        status: StudentStatus.left,
      );
      expect(byStatus, hasLength(1));

      final combined = await repository.searchStudents(
        status: StudentStatus.active,
        className: '3',
      );
      expect(combined, hasLength(1));
      expect(combined.single.student.name, 'Sara Khan');
    });

    test('distinct classes and sections are derived from the data', () async {
      await openDb();
      final family = await createFamily();
      await repository.createStudent(
        familyId: family.id,
        name: 'Ali Khan',
        className: '5',
        section: 'A',
      );
      await repository.createStudent(
        familyId: family.id,
        name: 'Sara Khan',
        className: '3',
        section: 'B',
      );

      expect(await repository.distinctClasses(), ['3', '5']);
      expect(await repository.distinctSections(), ['A', 'B']);
    });
  });

  group('duplicate detection', () {
    test('flags a matching admission number', () async {
      await openDb();
      final family = await createFamily();
      await repository.createStudent(
        familyId: family.id,
        name: 'Ali Khan',
        admissionNumber: 'ADM-100',
      );

      final matches = await repository.findPossibleStudentDuplicates(
        name: 'Different Name',
        admissionNumber: 'ADM-100',
        familyId: family.id,
      );
      expect(matches, hasLength(1));
      expect(matches.single.student.admissionNumber, 'ADM-100');
    });

    test('flags the same name in the same family', () async {
      await openDb();
      final family = await createFamily();
      await repository.createStudent(familyId: family.id, name: 'Ali Khan');

      final matches = await repository.findPossibleStudentDuplicates(
        name: 'Ali Khan',
        familyId: family.id,
      );
      expect(matches, hasLength(1));
    });

    test('flags the same name with a matching guardian phone', () async {
      await openDb();
      final family = await createFamily(phone: '0300-1234567');
      await repository.createStudent(familyId: family.id, name: 'Ali Khan');
      final other = await createFamily(phone: '0300-9999999');
      await repository.createStudent(familyId: other.id, name: 'Usman');

      final matches = await repository.findPossibleStudentDuplicates(
        name: 'Ali Khan',
        familyId: other.id,
        guardianName: other.guardianName,
        primaryPhone: '0300-1234567',
      );
      expect(matches, hasLength(1));
    });

    test('does not surface a name-only match', () async {
      await openDb();
      final family = await createFamily();
      await repository.createStudent(familyId: family.id, name: 'Ali Khan');

      final matches = await repository.findPossibleStudentDuplicates(
        name: 'Ali Khan',
        familyId: 98765,
        guardianName: 'Nobody',
        primaryPhone: '0300-0000000',
      );
      expect(matches, isEmpty);
    });

    test('respects excludeId so edits are not flagged as duplicates', () async {
      await openDb();
      final family = await createFamily();
      final student = await repository.createStudent(
        familyId: family.id,
        name: 'Ali Khan',
        admissionNumber: 'ADM-100',
      );

      final matches = await repository.findPossibleStudentDuplicates(
        excludeId: student.id,
        name: 'Ali Khan',
        admissionNumber: 'ADM-100',
        familyId: family.id,
      );
      expect(matches, isEmpty);
    });
  });

  group('student details and fees', () {
    test('details include family, admission history and fee summary', () async {
      await openDb();
      final family = await createFamily();
      final student = await repository.createStudent(
        familyId: family.id,
        name: 'Ali Khan',
        className: '5',
        admissionDate: DateTime(2024, 3, 1),
      );
      await repository.setStudentStatus(student.id, StudentStatus.active);

      final fee1 = await insertFeeRecord(
        studentId: student.id,
        id: 'FEE-000001',
        expected: 5000,
        paid: 2000,
      );
      await insertPayment(
        studentId: student.id,
        feeRecordId: fee1,
        amount: 2000,
      );
      final fee2 = await insertFeeRecord(
        studentId: student.id,
        id: 'FEE-000002',
        expected: 1000,
        paid: 1000,
        status: 'paid',
        periodStart: '2026-08-01',
        periodEnd: '2026-08-31',
      );
      await insertPayment(
        studentId: student.id,
        feeRecordId: fee2,
        amount: 1000,
      );

      final details = await repository.getStudentDetails(student.id);
      expect(details.family.familyId, 'FAM-000001');
      expect(details.family.guardianName, 'Ahmed Khan');
      expect(details.admissions, hasLength(1));
      expect(details.admissions.single.admissionDate, DateTime(2024, 3, 1));
      expect(details.outstandingFees, 3000);
      expect(details.feeHistory, hasLength(2));
      final outstanding = details.feeHistory.firstWhere(
        (f) => f.feeRecordCode == 'FEE-000001',
      );
      expect(outstanding.expected, 5000);
      expect(outstanding.paid, 2000);
      expect(outstanding.due, 3000);
      expect(outstanding.status, 'pending');
    });
  });

  group('performance', () {
    test('searches stay fast with thousands of students', () async {
      await openDb();
      final family = await createFamily();

      // Seed 5,000 students across 20 classes in one batch (test data only,
      // never production).
      await database!.raw.transaction((txn) async {
        final now = DateTime.now().toUtc().toIso8601String();
        final batch = txn.batch();
        for (var i = 1; i <= 5000; i++) {
          final classNo = (i % 20) + 1;
          final name = i % 500 == 0 ? 'Ali Khan' : 'Student $i';
          batch.insert('students', {
            'student_id': 'STU-${i.toString().padLeft(6, '0')}',
            'family_id': family.id,
            'name': name,
            'class': 'Class $classNo',
            'section': 'A',
            'status': i % 10 == 0 ? 'left' : 'active',
            'created_at': now,
            'updated_at': now,
          });
        }
        await batch.commit(noResult: true);
      });

      final sw = Stopwatch()..start();
      final exact = await repository.searchStudents(query: 'STU-004999');
      final exactMs = sw.elapsedMilliseconds;
      expect(exact, hasLength(1));
      expect(exact.single.student.name, 'Student 4999');

      sw
        ..reset()
        ..start();
      final byName = await repository.searchStudents(query: 'Ali Khan');
      final nameMs = sw.elapsedMilliseconds;
      expect(byName, hasLength(10));
      expect(byName.length, lessThanOrEqualTo(100));

      sw
        ..reset()
        ..start();
      final byClass = await repository.searchStudents(className: '7');
      final classMs = sw.elapsedMilliseconds;
      expect(byClass.length, lessThanOrEqualTo(100));

      sw
        ..reset()
        ..start();
      final byStatus = await repository.searchStudents(
        status: StudentStatus.left,
      );
      final statusMs = sw.elapsedMilliseconds;
      expect(byStatus.length, lessThanOrEqualTo(100));

      expect(exactMs, lessThan(1000));
      expect(nameMs, lessThan(1000));
      expect(classMs, lessThan(1000));
      expect(statusMs, lessThan(1000));
    });
  });
}
