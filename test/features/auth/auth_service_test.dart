import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/auth/domain/entities/app_role.dart';
import 'package:school_office_management/features/auth/domain/entities/app_user.dart';
import 'package:school_office_management/features/auth/domain/repositories/auth_repository.dart';
import 'package:school_office_management/features/auth/domain/services/auth_service.dart';

/// In-memory fake repository so the session/business logic can be tested
/// without a real database.
class FakeAuthRepository implements AuthRepository {
  final Map<String, FakeAccount> accounts = {};
  bool failAuthenticate = false;
  bool failCreate = false;
  bool failHasAny = false;

  @override
  Future<AppUser?> authenticate(String identifier, String password) async {
    if (failAuthenticate) throw Exception('simulated database failure');
    final account = accounts[identifier.trim().toLowerCase()];
    if (account == null) return null;
    if (account.password != password) return null;
    if (!account.user.isActive) return null;
    return account.user;
  }

  @override
  Future<AppUser> createUser({
    required String username,
    required String password,
    required String displayName,
    AppRole role = AppRole.dataEntry,
  }) async {
    if (failCreate) throw Exception('simulated database failure');
    final user = AppUser(
      id: accounts.length + 1,
      username: username.trim(),
      displayName: displayName.trim(),
      role: role,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    accounts[username.trim().toLowerCase()] = FakeAccount(password, user);
    return user;
  }

  @override
  Future<bool> hasAnyUser() async {
    if (failHasAny) throw Exception('simulated database failure');
    return accounts.isNotEmpty;
  }
}

class FakeAccount {
  FakeAccount(this.password, this.user);
  final String password;
  final AppUser user;
}

void main() {
  group('AuthService', () {
    late FakeAuthRepository repository;
    late AuthService service;

    setUp(() async {
      repository = FakeAuthRepository();
      await repository.createUser(
        username: 'admin',
        password: 'CorrectPass123',
        displayName: 'Admin User',
        role: AppRole.schoolAdmin,
      );
      service = AuthService(repository);
      await service.refreshSetupStatus();
    });

    test('9. initially no active session', () {
      expect(service.isAuthenticated, isFalse);
      expect(service.currentUser, isNull);
    });

    test('1. correct credentials create an authenticated session', () async {
      final result = await service.login('admin', 'CorrectPass123');
      expect(result, AuthResult.success);
      expect(service.isAuthenticated, isTrue);
      expect(service.currentUser?.displayName, 'Admin User');
    });

    test('2. wrong password fails and leaves session empty', () async {
      final result = await service.login('admin', 'WrongPass');
      expect(result, AuthResult.invalidCredentials);
      expect(service.isAuthenticated, isFalse);
      expect(service.currentUser, isNull);
    });

    test('3. unknown account fails identically', () async {
      final result = await service.login('unknown', 'CorrectPass123');
      expect(result, AuthResult.invalidCredentials);
      expect(service.isAuthenticated, isFalse);
    });

    test('5. inactive account fails identically', () async {
      final active = repository.accounts['admin']!;
      final inactiveUser = AppUser(
        id: active.user.id,
        username: active.user.username,
        displayName: active.user.displayName,
        role: active.user.role,
        isActive: false,
        createdAt: active.user.createdAt,
        updatedAt: active.user.updatedAt,
      );
      repository.accounts['admin'] = FakeAccount(active.password, inactiveUser);

      final result = await service.login('admin', 'CorrectPass123');
      expect(result, AuthResult.invalidCredentials);
      expect(service.isAuthenticated, isFalse);
    });

    test('6. logout clears the session', () async {
      await service.login('admin', 'CorrectPass123');
      expect(service.isAuthenticated, isTrue);

      service.logout();
      expect(service.isAuthenticated, isFalse);
      expect(service.currentUser, isNull);
    });

    test('7. restart (new service instance) requires login again', () async {
      await service.login('admin', 'CorrectPass123');
      expect(service.isAuthenticated, isTrue);

      // A fresh launch constructs a brand-new service; nothing is persisted.
      final restarted = AuthService(repository);
      await restarted.refreshSetupStatus();
      expect(restarted.isAuthenticated, isFalse);
      expect(restarted.currentUser, isNull);
    });

    test('8. database error during login returns databaseError', () async {
      repository.failAuthenticate = true;
      final result = await service.login('admin', 'CorrectPass123');
      expect(result, AuthResult.databaseError);
      expect(service.isAuthenticated, isFalse);
    });

    test('8b. notifyListeners fires on login and logout', () async {
      var notified = 0;
      service.addListener(() => notified++);

      await service.login('admin', 'CorrectPass123');
      service.logout();

      expect(notified, 2);
    });

    group('first-run setup', () {
      test('refreshSetupStatus detects an empty database', () async {
        final emptyRepo = FakeAuthRepository();
        final emptyService = AuthService(emptyRepo);
        expect(emptyService.setupRequired, isTrue);

        await emptyService.refreshSetupStatus();
        expect(emptyService.setupRequired, isTrue);
      });

      test('refreshSetupStatus detects an existing account', () async {
        await service.refreshSetupStatus();
        expect(service.setupRequired, isFalse);
      });

      test(
        'createInitialAdmin creates account, completeSetup flips state',
        () async {
          final emptyRepo = FakeAuthRepository();
          final emptyService = AuthService(emptyRepo);
          await emptyService.refreshSetupStatus();
          expect(emptyService.setupRequired, isTrue);

          final result = await emptyService.createInitialAdmin(
            displayName: 'Head Master',
            username: 'headmaster',
            password: 'StrongPass1',
          );
          expect(result, AuthResult.success);
          expect(emptyService.setupRequired, isTrue); // not yet flipped

          emptyService.completeSetup();
          expect(emptyService.setupRequired, isFalse);
          expect(await emptyRepo.hasAnyUser(), isTrue);
        },
      );

      test('createInitialAdmin surfaces database errors', () async {
        final emptyRepo = FakeAuthRepository()..failCreate = true;
        final emptyService = AuthService(emptyRepo);

        final result = await emptyService.createInitialAdmin(
          displayName: 'Head Master',
          username: 'headmaster',
          password: 'StrongPass1',
        );
        expect(result, AuthResult.databaseError);
      });
    });
  });
}
