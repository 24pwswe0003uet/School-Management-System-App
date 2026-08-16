import 'package:sqflite/sqflite.dart';
import 'package:school_office_management/core/database/app_database.dart';
import 'package:school_office_management/core/database/database_factory.dart';
import 'package:school_office_management/features/auth/domain/services/auth_service.dart';
import 'package:school_office_management/features/backup/domain/entities/backup_record.dart';
import 'package:school_office_management/features/backup/domain/services/backup_service.dart';

import 'fakes/fake_backup_repository.dart';
import '../settings/helpers.dart';
export '../settings/helpers.dart';

/// Opens a fresh in-memory database (runs all migrations) for testing.
Future<AppDatabase> openTestDatabase() async {
  initDatabaseFactory();
  return AppDatabase.open(path: inMemoryDatabasePath);
}

/// Builds a [BackupService] wired to a fresh in-memory database and the given
/// auth state. The same service instance must be reused within a test.
Future<BackupService> buildBackupService({
  AuthService? authService,
  FakeBackupRepository? repository,
  AppDatabase? database,
  Future<String> Function()? liveDatabasePath,
}) async {
  final db = database ?? await openTestDatabase();
  final auth = authService ?? await buildTestAdminAuthService();
  final repo = repository ?? FakeBackupRepository();
  return BackupService(
    database: db,
    repository: repo,
    authService: auth,
    liveDatabasePath: liveDatabasePath ?? () async => '/tmp/test_live.db',
  );
}

/// A [BackupRecord] pointing at [path], large enough to be considered valid.
BackupRecord testBackupRecord({
  String path = '/tmp/backups/school_backup.db',
  int schemaVersion = 12,
}) {
  return BackupRecord(
    path: path,
    createdAt: DateTime(2026, 8, 15, 10, 0, 0),
    sizeBytes: 2048,
    schemaVersion: schemaVersion,
    status: BackupStatus.successful,
  );
}
