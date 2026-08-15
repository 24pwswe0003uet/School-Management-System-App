import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/core/database/app_database.dart';
import 'package:school_office_management/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:school_office_management/features/auth/domain/entities/app_role.dart';
import 'package:school_office_management/features/auth/domain/entities/app_user.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppDatabase? database;
  late AuthRepositoryImpl repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> openDb() async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    database = db;
    repository = AuthRepositoryImpl(db);
  }

  tearDown(() async {
    await database?.close();
    database = null;
  });

  group('users table / migration', () {
    test('schema_versions and users tables exist after open', () async {
      await openDb();
      final versions = await database!.raw.rawQuery(
        'SELECT version FROM schema_versions ORDER BY version',
      );
      expect(
        versions.map((r) => r['version']).toList(),
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      );
    });
  });

  group('AuthRepositoryImpl', () {
    test('1. correct credentials authenticate successfully', () async {
      await openDb();
      await repository.createUser(
        username: 'admin',
        password: 'CorrectPass123',
        displayName: 'Admin User',
        role: AppRole.schoolAdmin,
      );

      final user = await repository.authenticate('admin', 'CorrectPass123');
      expect(user, isNotNull);
      expect(user!.displayName, 'Admin User');
      expect(user.role, AppRole.schoolAdmin);
      expect(user.isActive, isTrue);
    });

    test('1b. username matching is case-insensitive', () async {
      await openDb();
      await repository.createUser(
        username: 'Admin',
        password: 'CorrectPass123',
        displayName: 'Admin User',
      );

      final user = await repository.authenticate('  ADMIN ', 'CorrectPass123');
      expect(user, isNotNull);
    });

    test('2. wrong password returns null', () async {
      await openDb();
      await repository.createUser(
        username: 'admin',
        password: 'CorrectPass123',
        displayName: 'Admin User',
      );

      expect(await repository.authenticate('admin', 'WrongPass'), isNull);
    });

    test('3. unknown account returns null', () async {
      await openDb();
      await repository.createUser(
        username: 'admin',
        password: 'CorrectPass123',
        displayName: 'Admin User',
      );

      expect(await repository.authenticate('nobody', 'CorrectPass123'), isNull);
    });

    test('5. inactive account fails to authenticate', () async {
      await openDb();
      await repository.createUser(
        username: 'admin',
        password: 'CorrectPass123',
        displayName: 'Admin User',
      );
      await database!.raw.update(
        'users',
        {'is_active': 0},
        where: 'username = ?',
        whereArgs: ['admin'],
      );

      expect(await repository.authenticate('admin', 'CorrectPass123'), isNull);
    });

    test('10. password is never stored as plain text', () async {
      await openDb();
      await repository.createUser(
        username: 'admin',
        password: 'TopSecretPass!',
        displayName: 'Admin User',
      );

      final rows = await database!.raw.rawQuery(
        'SELECT password_hash FROM users',
      );
      expect(rows, hasLength(1));
      final stored = rows.first['password_hash'] as String;
      expect(stored, isNot(contains('TopSecretPass!')));
      expect(stored.startsWith('pbkdf2-sha256\$'), isTrue);
    });

    test('duplicate username is rejected by unique constraint', () async {
      await openDb();
      await repository.createUser(
        username: 'admin',
        password: 'CorrectPass123',
        displayName: 'One',
      );

      expect(
        () => repository.createUser(
          username: 'ADMIN',
          password: 'OtherPass123',
          displayName: 'Two',
        ),
        throwsA(
          isA<DatabaseException>().having(
            (e) => e.isUniqueConstraintError(),
            'unique constraint',
            isTrue,
          ),
        ),
      );
    });

    test('hasAnyUser reflects account existence', () async {
      await openDb();
      expect(await repository.hasAnyUser(), isFalse);
      await repository.createUser(
        username: 'admin',
        password: 'CorrectPass123',
        displayName: 'Admin User',
      );
      expect(await repository.hasAnyUser(), isTrue);
    });

    test('returned AppUser exposes only safe fields (no hash)', () async {
      await openDb();
      final user = await repository.createUser(
        username: 'admin',
        password: 'CorrectPass123',
        displayName: 'Admin User',
        role: AppRole.dataEntry,
      );
      expect(user, isA<AppUser>());
      expect(user.id, greaterThan(0));
      expect(user.role, AppRole.dataEntry);
      expect(user.createdAt.isUtc, isTrue);
    });

    test('8. database unavailable surfaces an error to the caller', () async {
      await openDb();
      await repository.createUser(
        username: 'admin',
        password: 'CorrectPass123',
        displayName: 'Admin User',
      );
      await database!.close();

      await expectLater(
        () => repository.authenticate('admin', 'CorrectPass123'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
