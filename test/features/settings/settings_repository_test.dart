import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/core/database/app_database.dart';
import 'package:school_office_management/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:school_office_management/features/settings/domain/entities/school_profile.dart';
import 'package:school_office_management/features/settings/domain/repositories/settings_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// In-memory [LogoStore] standing in for the file store on IO platforms.
class _MemoryLogoStore implements LogoStore {
  Uint8List? bytes;
  String? mime;
  int writeCount = 0;

  @override
  Future<Uint8List?> read() async => bytes;

  @override
  Future<void> write({required Uint8List bytes, required String mimeType}) async {
    this.bytes = bytes;
    mime = mimeType;
    writeCount++;
  }

  @override
  Future<void> remove() async {
    bytes = null;
    mime = null;
  }
}

/// A [LogoStore] that always fails — forces the BLOB fallback path (web).
class _FailingLogoStore implements LogoStore {
  @override
  Future<Uint8List?> read() async => null;

  @override
  Future<void> write({required Uint8List bytes, required String mimeType}) async {
    throw UnsupportedError('no filesystem');
  }

  @override
  Future<void> remove() async {
    throw UnsupportedError('no filesystem');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppDatabase? database;
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<SettingsRepositoryImpl> openRepo(
    String path,
    LogoStore store,
  ) async {
    final appDb = await AppDatabase.open(path: path);
    database = appDb;
    db = appDb.raw;
    return SettingsRepositoryImpl(db, store);
  }

  tearDown(() async {
    await database?.close();
    database = null;
  });

  const ts = '2026-08-01T00:00:00Z';

  var seedCounter = 0;

  Future<void> seedStudent({
    String classValue = '5',
    String sectionValue = 'A',
    String status = 'active',
  }) async {
    seedCounter++;
    final suffix = seedCounter;
    final familyId = await db.insert('families', {
      'family_id': 'FAM-TEST-$suffix',
      'guardian_name': 'Test Guardian',
      'created_at': ts,
      'updated_at': ts,
    });
    await db.insert('students', {
      'student_id': 'STU-TEST-$suffix',
      'family_id': familyId,
      'name': 'Ali Khan',
      'class': classValue,
      'section': sectionValue,
      'status': status,
      'created_at': ts,
      'updated_at': ts,
    });
  }

  group('profile', () {
    test('defaults to an empty profile', () async {
      final repo = await openRepo(inMemoryDatabasePath, _MemoryLogoStore());
      final profile = await repo.getProfile();
      expect(profile.schoolName, '');
      expect(profile.hasLogo, isFalse);
      expect(profile.logoKind, LogoKind.none);
    });

    test('saveProfile persists every field and returns it', () async {
      final repo = await openRepo(inMemoryDatabasePath, _MemoryLogoStore());
      final saved = await repo.saveProfile(
        schoolName: 'Bright Future School',
        address: 'Main Road',
        phone: '0300-1234567',
        email: 'info@bfs.edu.pk',
        academicYear: '2025–2026',
        receiptFooter: 'Thank you for paying on time.',
      );
      expect(saved.schoolName, 'Bright Future School');
      expect(saved.receiptFooter, 'Thank you for paying on time.');

      final reread = await repo.getProfile();
      expect(reread.schoolName, 'Bright Future School');
      expect(reread.phone, '0300-1234567');
      expect(reread.academicYear, '2025–2026');
    });

    test('logo stored through the file store is read back', () async {
      final store = _MemoryLogoStore();
      final repo = await openRepo(inMemoryDatabasePath, store);
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      final updated = await repo.updateLogo(bytes: bytes, mimeType: 'image/png');

      expect(updated.hasLogo, isTrue);
      expect(updated.logoKind, LogoKind.file);
      expect(updated.logoFileName, 'school_logo.png');
      expect(store.writeCount, 1);
      expect(await repo.getLogoBytes(), bytes);

      final removed = await repo.removeLogo();
      expect(removed.hasLogo, isFalse);
      expect(await repo.getLogoBytes(), isNull);
    });

    test('logo falls back to a BLOB when the file store fails (web)', () async {
      final repo = await openRepo(
        inMemoryDatabasePath,
        _FailingLogoStore(),
      );
      final bytes = Uint8List.fromList([9, 8, 7]);

      final updated = await repo.updateLogo(
        bytes: bytes,
        mimeType: 'image/jpeg',
      );

      expect(updated.logoKind, LogoKind.blob);
      expect(await repo.getLogoBytes(), bytes);

      final removed = await repo.removeLogo();
      expect(removed.hasLogo, isFalse);
      expect(await repo.getLogoBytes(), isNull);
    });
  });

  group('persistence across reopen', () {
    test('profile survives closing and reopening the database', () async {
      final dir = await Directory.systemTemp.createTemp('settings_test_');
      final path = '${dir.path}/test.db';
      try {
        final firstDb = await AppDatabase.open(path: path);
        final firstRepo = SettingsRepositoryImpl(firstDb.raw, _MemoryLogoStore());
        await firstRepo.saveProfile(schoolName: 'Reopen School');
        await firstDb.close();

        final secondDb = await AppDatabase.open(path: path);
        final secondRepo =
            SettingsRepositoryImpl(secondDb.raw, _MemoryLogoStore());
        expect((await secondRepo.getProfile()).schoolName, 'Reopen School');
        final classes = await secondRepo.listClasses(includeInactive: true);
        expect(classes, isNotEmpty);
        expect(classes.first.className, isNotEmpty);
        await secondDb.close();
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('classes', () {
    test('migration seeds the canonical default classes', () async {
      final repo = await openRepo(inMemoryDatabasePath, _MemoryLogoStore());
      final classes = await repo.listClasses(includeInactive: true);
      final names = classes.map((c) => c.className).toList();
      expect(names, containsAll(['Play Group', 'Nursery', 'KG', '1', '12']));
      expect(classes.every((c) => c.isActive), isTrue);
    });

    test('listClasses hides inactive classes unless requested', () async {
      final repo = await openRepo(inMemoryDatabasePath, _MemoryLogoStore());
      final class5 = (await repo.listClasses(includeInactive: true))
          .firstWhere((c) => c.className == '5');
      await repo.setClassActive(class5.id, false);

      final active = await repo.listClasses();
      expect(active.any((c) => c.className == '5'), isFalse);

      final all = await repo.listClasses(includeInactive: true);
      expect(all.any((c) => c.className == '5'), isTrue);
    });

    test('addClass creates an active class and trims the name', () async {
      final repo = await openRepo(inMemoryDatabasePath, _MemoryLogoStore());
      final created = await repo.addClass('  Advanced  ');

      expect(created.className, 'Advanced');
      expect(created.isActive, isTrue);
      expect(created.id, greaterThan(0));
      expect(
        (await repo.listClasses()).any((c) => c.className == 'Advanced'),
        isTrue,
      );
    });

    test('duplicate class name throws DuplicateSettingsNameException', () async {
      final repo = await openRepo(inMemoryDatabasePath, _MemoryLogoStore());
      await expectLater(
        repo.addClass('5'),
        throwsA(
          isA<DuplicateSettingsNameException>()
              .having((e) => e.kind, 'kind', 'Class'),
        ),
      );
    });

    test('activeStudentCount counts active students in the class', () async {
      final repo = await openRepo(inMemoryDatabasePath, _MemoryLogoStore());
      await seedStudent(classValue: '5');
      await seedStudent(classValue: '5', status: 'left');

      final class5 = (await repo.listClasses())
          .firstWhere((c) => c.className == '5');
      expect(class5.activeStudentCount, 1);
    });

    test('updateClass renames the row and migrates students when asked', () async {
      final repo = await openRepo(inMemoryDatabasePath, _MemoryLogoStore());
      await seedStudent(classValue: '5');
      final class5 = (await repo.listClasses(includeInactive: true))
          .firstWhere((c) => c.className == '5');

      final updated = await repo.updateClass(
        id: class5.id,
        className: 'Five',
        renameStudents: true,
      );

      expect(updated.className, 'Five');
      final rows = await db.query('students');
      expect(rows.single['class'], 'Five');
      expect(
        (await repo.listClasses(includeInactive: true))
            .firstWhere((c) => c.id == class5.id)
            .activeStudentCount,
        1,
      );
    });

    test('updateClass without migration keeps student values', () async {
      final repo = await openRepo(inMemoryDatabasePath, _MemoryLogoStore());
      await seedStudent(classValue: '5');
      final class5 = (await repo.listClasses(includeInactive: true))
          .firstWhere((c) => c.className == '5');

      await repo.updateClass(id: class5.id, className: 'Five');

      final rows = await db.query('students');
      expect(rows.single['class'], '5');
    });

    test('renaming onto an existing name throws DuplicateSettingsNameException',
        () async {
      final repo = await openRepo(inMemoryDatabasePath, _MemoryLogoStore());
      await repo.addClass('Sixth');
      final class5 = (await repo.listClasses(includeInactive: true))
          .firstWhere((c) => c.className == '5');

      await expectLater(
        repo.updateClass(id: class5.id, className: 'Sixth'),
        throwsA(isA<DuplicateSettingsNameException>()),
      );
    });
  });

  group('sections', () {
    test('migration seeds A, B, C and listSections hides inactive', () async {
      final repo = await openRepo(inMemoryDatabasePath, _MemoryLogoStore());
      final sections = await repo.listSections(includeInactive: true);
      expect(sections.map((s) => s.sectionName).toList(), containsAll(['A', 'B', 'C']));

      final sectionA = sections.firstWhere((s) => s.sectionName == 'A');
      await repo.setSectionActive(sectionA.id, false);

      final active = await repo.listSections();
      expect(active.any((s) => s.sectionName == 'A'), isFalse);
    });

    test('addSection trims and duplicate throws', () async {
      final repo = await openRepo(inMemoryDatabasePath, _MemoryLogoStore());
      final created = await repo.addSection('  D  ');
      expect(created.sectionName, 'D');

      await expectLater(
        repo.addSection('A'),
        throwsA(
          isA<DuplicateSettingsNameException>()
              .having((e) => e.kind, 'kind', 'Section'),
        ),
      );
    });

    test('updateSection migrates students when asked', () async {
      final repo = await openRepo(inMemoryDatabasePath, _MemoryLogoStore());
      await seedStudent(sectionValue: 'A');
      final sectionA = (await repo.listSections(includeInactive: true))
          .firstWhere((s) => s.sectionName == 'A');

      await repo.updateSection(id: sectionA.id, sectionName: 'Alpha',
          renameStudents: true);

      final rows = await db.query('students');
      expect(rows.single['section'], 'Alpha');
    });

    test('activeStudentCount counts active students in the section', () async {
      final repo = await openRepo(inMemoryDatabasePath, _MemoryLogoStore());
      await seedStudent(sectionValue: 'A');

      final sectionA = (await repo.listSections())
          .firstWhere((s) => s.sectionName == 'A');
      expect(sectionA.activeStudentCount, 1);
    });
  });
}
