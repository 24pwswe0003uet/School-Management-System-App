import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/core/database/app_database.dart';
import 'package:school_office_management/features/family/data/repositories/family_repository_impl.dart';
import 'package:school_office_management/features/family/domain/entities/family.dart';
import 'package:school_office_management/features/family/domain/repositories/family_has_linked_students_exception.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppDatabase? database;
  late FamilyRepositoryImpl repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> openDb() async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    database = db;
    repository = FamilyRepositoryImpl(db.raw);
  }

  tearDown(() async {
    await database?.close();
    database = null;
  });

  const ts = '2026-08-01T00:00:00Z';

  Future<int> insertStudent({
    required int familyId,
    String id = 'STU-000001',
    String name = 'Ali Khan',
    String className = '5',
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

  Future<void> insertPayment({
    required int studentId,
    required int feeRecordId,
    double amount = 0,
    String date = '2026-08-10',
  }) async {
    await database!.raw.insert('payments', {
      'payment_id': 'PAY-$studentId-$feeRecordId',
      'student_id': studentId,
      'fee_record_id': feeRecordId,
      'amount': amount,
      'payment_date': date,
      'created_at': ts,
    });
  }

  group('create family', () {
    test('creates a family with a generated ID and normalizes CNIC', () async {
      await openDb();
      final family = await repository.createFamily(
        guardianName: '  Ahmed Khan  ',
        motherName: 'Sara Khan',
        primaryPhone: '0300-1234567',
        address: 'House 4, Main Street',
        cnic: '1234512345671',
      );

      expect(family.familyId, 'FAM-000001');
      expect(family.guardianName, 'Ahmed Khan');
      expect(family.cnic, '12345-1234567-1');
      expect(family.status, FamilyStatus.active);

      final loaded = await repository.getFamily(family.id);
      expect(loaded?.familyId, 'FAM-000001');
      expect(loaded?.motherName, 'Sara Khan');
    });

    test('second family gets the next sequential ID', () async {
      await openDb();
      await repository.createFamily(guardianName: 'First');
      final second = await repository.createFamily(guardianName: 'Second');
      expect(second.familyId, 'FAM-000002');
    });

    test('rejects an empty guardian name', () async {
      await openDb();
      await expectLater(
        repository.createFamily(guardianName: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('duplicate family ID is rejected by the unique constraint', () async {
      await openDb();
      await repository.createFamily(guardianName: 'First');
      await expectLater(
        database!.raw.insert('families', {
          'family_id': 'FAM-000001',
          'guardian_name': 'Dupe',
          'created_at': ts,
          'updated_at': ts,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('edit family', () {
    test('updates fields but keeps the family ID', () async {
      await openDb();
      final family = await repository.createFamily(
        guardianName: 'Old Name',
        primaryPhone: '111',
      );
      final updated = await repository.updateFamily(
        id: family.id,
        guardianName: 'New Name',
        primaryPhone: '0300-7654321',
        secondaryPhone: '222',
      );

      expect(updated.familyId, 'FAM-000001');
      expect(updated.guardianName, 'New Name');
      expect(updated.primaryPhone, '0300-7654321');
      expect(updated.secondaryPhone, '222');

      final loaded = await repository.getFamily(family.id);
      expect(loaded?.motherName, isNull);
    });

    test('rejects an empty guardian name on edit', () async {
      await openDb();
      final family = await repository.createFamily(guardianName: 'Name');
      await expectLater(
        repository.updateFamily(id: family.id, guardianName: ''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('search family', () {
    test('searches by family ID', () async {
      await openDb();
      await repository.createFamily(guardianName: 'Ahmed Khan');
      final results = await repository.searchFamilies('FAM-000001');
      expect(results.single.family.guardianName, 'Ahmed Khan');
    });

    test('searches by guardian name case-insensitively', () async {
      await openDb();
      await repository.createFamily(guardianName: 'Ahmed Khan');
      final results = await repository.searchFamilies('ahmed');
      expect(results.single.family.guardianName, 'Ahmed Khan');
    });

    test('searches by mother name', () async {
      await openDb();
      await repository.createFamily(guardianName: 'X', motherName: 'Sara Khan');
      final results = await repository.searchFamilies('sara');
      expect(results.single.family.guardianName, 'X');
    });

    test('phone search ignores dashes and spaces', () async {
      await openDb();
      await repository.createFamily(
        guardianName: 'X',
        primaryPhone: '03001234567',
      );
      final results = await repository.searchFamilies('0300-1234567');
      expect(results, hasLength(1));
    });

    test('searches by a linked student name', () async {
      await openDb();
      final family = await repository.createFamily(guardianName: 'Ahmed Khan');
      await insertStudent(familyId: family.id, name: 'Usman Khan');

      final results = await repository.searchFamilies('usman');
      expect(results.single.family.familyId, 'FAM-000001');
      expect(results.single.studentCount, 1);
    });

    test('empty query returns all families', () async {
      await openDb();
      await repository.createFamily(guardianName: 'A');
      await repository.createFamily(guardianName: 'B');
      final results = await repository.searchFamilies('');
      expect(results, hasLength(2));
    });
  });

  group('duplicate detection', () {
    test('similar families are never merged and are detected', () async {
      await openDb();
      await repository.createFamily(
        guardianName: 'Ahmed Khan',
        primaryPhone: '0300-1234567',
        address: 'House 4, Main Street',
      );
      await repository.createFamily(
        guardianName: 'Ahmed Khan',
        primaryPhone: '0300-9999999',
        address: 'House 9, Side Lane',
      );

      final all = await repository.searchFamilies('');
      expect(all, hasLength(2));

      final dups = await repository.findPossibleDuplicates(
        guardianName: 'Ahmed Khan',
        primaryPhone: '0300-1234567',
        address: 'House 4, Main Street',
      );
      expect(dups, hasLength(1));
      expect(dups.single.familyId, 'FAM-000001');
    });

    test('detects duplicates by phone digits alone', () async {
      await openDb();
      await repository.createFamily(
        guardianName: 'First',
        primaryPhone: '0300-1234567',
      );
      final dups = await repository.findPossibleDuplicates(
        primaryPhone: '03001234567',
      );
      expect(dups.single.familyId, 'FAM-000001');
    });

    test('excludeId ignores the family being edited', () async {
      await openDb();
      final family = await repository.createFamily(guardianName: 'Ahmed Khan');
      final dups = await repository.findPossibleDuplicates(
        guardianName: 'Ahmed Khan',
        excludeId: family.id,
      );
      expect(dups, isEmpty);
    });

    test('no duplicates when fields differ', () async {
      await openDb();
      await repository.createFamily(
        guardianName: 'Ahmed Khan',
        primaryPhone: '0300-1111111',
      );
      final dups = await repository.findPossibleDuplicates(
        guardianName: 'Usman Ali',
        primaryPhone: '0300-2222222',
      );
      expect(dups, isEmpty);
    });
  });

  group('students and deletion rules', () {
    test('links multiple students and shows them in details', () async {
      await openDb();
      final family = await repository.createFamily(guardianName: 'Khan');
      await insertStudent(familyId: family.id, name: 'Ali', id: 'STU-000001');
      await insertStudent(familyId: family.id, name: 'Usman', id: 'STU-000002');
      await insertStudent(
        familyId: family.id,
        name: 'Fatima',
        id: 'STU-000003',
        className: '7',
        status: 'transferred',
      );

      final details = await repository.getFamilyDetails(family.id);
      expect(details.studentCount, 3);
      expect(details.students.map((s) => s.name).toList(), [
        'Ali',
        'Fatima',
        'Usman',
      ]);
      expect(details.students[1].status, 'transferred');
      expect(details.students[1].className, '7');
    });

    test('prevents orphan students (foreign key)', () async {
      await openDb();
      await expectLater(
        insertStudent(familyId: 99999),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('deleting a family with linked students is refused', () async {
      await openDb();
      final family = await repository.createFamily(guardianName: 'Khan');
      await insertStudent(familyId: family.id);

      await expectLater(
        repository.deleteFamily(family.id),
        throwsA(isA<FamilyHasLinkedStudentsException>()),
      );
      expect(await repository.getFamily(family.id), isNotNull);
    });

    test('deleting an empty family succeeds and reuses the ID', () async {
      await openDb();
      final family = await repository.createFamily(guardianName: 'Khan');
      await repository.deleteFamily(family.id);

      expect(await repository.getFamily(family.id), isNull);
      expect(await repository.nextFamilyId(), 'FAM-000001');
    });

    test('archive and unarchive toggle status', () async {
      await openDb();
      final family = await repository.createFamily(guardianName: 'Khan');
      final archived = await repository.archiveFamily(family.id);
      expect(archived.status, FamilyStatus.inactive);

      final active = await repository.unarchiveFamily(family.id);
      expect(active.status, FamilyStatus.active);
    });
  });

  group('family outstanding fees', () {
    test(
      'computes combined outstanding for the family students only',
      () async {
        await openDb();
        final family = await repository.createFamily(guardianName: 'Khan');
        final otherFamily = await repository.createFamily(
          guardianName: 'Other',
        );
        final student = await insertStudent(familyId: family.id, id: 'STU-1');
        final otherStudent = await insertStudent(
          familyId: otherFamily.id,
          id: 'STU-2',
        );

        final pendingFee = await database!.raw.insert('fee_records', {
          'fee_record_id': 'FEE-1',
          'student_id': student,
          'period_start': '2026-08-01',
          'period_end': '2026-08-31',
          'expected_amount': 5000,
          'discount': 0,
          'fine': 0,
          'net_payable': 5000,
          'paid_amount': 1000,
          'remaining_amount': 4000,
          'status': 'pending',
          'created_at': ts,
          'updated_at': ts,
        });
        await database!.raw.insert('fee_records', {
          'fee_record_id': 'FEE-2',
          'student_id': student,
          'period_start': '2026-09-01',
          'period_end': '2026-09-30',
          'expected_amount': 3000,
          'discount': 0,
          'fine': 0,
          'net_payable': 3000,
          'paid_amount': 0,
          'remaining_amount': 3000,
          'status': 'partial',
          'created_at': ts,
          'updated_at': ts,
        });
        await database!.raw.insert('fee_records', {
          'fee_record_id': 'FEE-3',
          'student_id': student,
          'period_start': '2026-10-01',
          'period_end': '2026-10-31',
          'expected_amount': 9999,
          'discount': 0,
          'fine': 0,
          'net_payable': 9999,
          'paid_amount': 0,
          'remaining_amount': 9999,
          'status': 'cancelled',
          'created_at': ts,
          'updated_at': ts,
        });
        await insertPayment(
          studentId: student,
          feeRecordId: pendingFee,
          amount: 1000,
        );
        // A fee record on another family must not leak in.
        await database!.raw.insert('fee_records', {
          'fee_record_id': 'FEE-4',
          'student_id': otherStudent,
          'period_start': '2026-08-01',
          'period_end': '2026-08-31',
          'expected_amount': 5000,
          'discount': 0,
          'fine': 0,
          'net_payable': 5000,
          'paid_amount': 1000,
          'remaining_amount': 4000,
          'status': 'pending',
          'created_at': ts,
          'updated_at': ts,
        });
        await database!.raw.insert('fee_records', {
          'fee_record_id': 'FEE-5',
          'student_id': otherStudent,
          'period_start': '2026-09-01',
          'period_end': '2026-09-30',
          'expected_amount': 3000,
          'discount': 0,
          'fine': 0,
          'net_payable': 3000,
          'paid_amount': 0,
          'remaining_amount': 3000,
          'status': 'partial',
          'created_at': ts,
          'updated_at': ts,
        });
        await database!.raw.insert('fee_records', {
          'fee_record_id': 'FEE-6',
          'student_id': otherStudent,
          'period_start': '2026-10-01',
          'period_end': '2026-10-31',
          'expected_amount': 9999,
          'discount': 0,
          'fine': 0,
          'net_payable': 9999,
          'paid_amount': 0,
          'remaining_amount': 9999,
          'status': 'cancelled',
          'created_at': ts,
          'updated_at': ts,
        });

        final details = await repository.getFamilyDetails(family.id);
        expect(details.outstandingFees, 7000);
        final other = await repository.getFamilyDetails(otherFamily.id);
        expect(other.outstandingFees, 7000);
      },
    );
  });
}
