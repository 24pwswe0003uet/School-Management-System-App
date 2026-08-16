import 'package:school_office_management/features/auth/domain/entities/app_role.dart';
import 'package:school_office_management/features/auth/domain/entities/app_user.dart';
import 'package:school_office_management/features/auth/domain/repositories/auth_repository.dart';
import 'package:school_office_management/features/auth/domain/services/auth_service.dart';
import 'package:school_office_management/features/settings/domain/repositories/settings_repository.dart';
import 'package:school_office_management/features/settings/domain/services/settings_service.dart';

import 'fakes/fake_settings_repository.dart';

class _AdminAuthRepository implements AuthRepository {
  @override
  Future<AppUser?> authenticate(String identifier, String password) async {
    return AppUser(
      id: 1,
      username: 'admin',
      displayName: 'Admin User',
      role: AppRole.schoolAdmin,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<AppUser> createUser({
    required String username,
    required String password,
    required String displayName,
    AppRole role = AppRole.dataEntry,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> hasAnyUser() async => true;
}

class _DataEntryAuthRepository implements AuthRepository {
  @override
  Future<AppUser?> authenticate(String identifier, String password) async {
    return AppUser(
      id: 2,
      username: 'clerk',
      displayName: 'Data Entry Clerk',
      role: AppRole.dataEntry,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<AppUser> createUser({
    required String username,
    required String password,
    required String displayName,
    AppRole role = AppRole.dataEntry,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> hasAnyUser() async => true;
}

/// An [AuthService] whose current user is the school admin.
Future<AuthService> buildTestAdminAuthService() async {
  final service = AuthService(_AdminAuthRepository());
  await service.refreshSetupStatus();
  await service.login('admin', 'password');
  return service;
}

/// An [AuthService] whose current user is a data-entry clerk (read-only
/// settings access).
Future<AuthService> buildTestDataEntryAuthService() async {
  final service = AuthService(_DataEntryAuthRepository());
  await service.refreshSetupStatus();
  await service.login('clerk', 'password');
  return service;
}

/// A loaded [SettingsService] backed by [FakeSettingsRepository] (pre-seeded
/// with the default classes/sections). Pass an [authService] to reuse an
/// already-logged-in service.
Future<SettingsService> buildTestSettingsService({
  AuthService? authService,
  SettingsRepository? repository,
}) async {
  final service = SettingsService(
    repository: repository ?? FakeSettingsRepository(),
    authService: authService ?? await buildTestAdminAuthService(),
  );
  await service.load();
  return service;
}
