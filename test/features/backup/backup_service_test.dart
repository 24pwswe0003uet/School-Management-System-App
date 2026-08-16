import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/backup/domain/entities/backup_record.dart';
import 'package:school_office_management/features/backup/domain/entities/backup_verification.dart';
import 'package:school_office_management/features/backup/domain/exceptions.dart';
import 'package:school_office_management/features/backup/domain/services/backup_service.dart';
import 'package:school_office_management/features/backup/domain/entities/backup_result.dart';

import 'fakes/fake_backup_repository.dart';
import 'helpers.dart';

BackupVerification _ok(int version) => BackupVerification(
      exists: true,
      sizeBytes: 2048,
      readable: true,
      integrityOk: true,
      tablesPresent: true,
      schemaVersion: version,
    );

BackupVerification _bad(String reason) => BackupVerification.failed(reason);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupService.createBackup', () {
    test('admin creates a verified backup', () async {
      final repo = FakeBackupRepository(
        createBackupResult: testBackupRecord(),
      );
      final service = await buildBackupService(repository: repo);

      final result = await service.createBackup();

      expect(result.success, isTrue);
      expect(result.record?.path, '/tmp/backups/school_backup.db');
      expect(repo.createBackupCalls, isNotEmpty);
      expect(repo.nextBackupPathCalls, isNotEmpty);
      expect(service.error, isNull);
    });

    test('non-admin is rejected with a permission failure', () async {
      final repo = FakeBackupRepository(createBackupResult: testBackupRecord());
      final service = await buildBackupService(
        repository: repo,
        authService: await buildTestDataEntryAuthService(),
      );

      final result = await service.createBackup();

      expect(result.success, isFalse);
      expect(result.message, contains('administrator'));
      expect(repo.createBackupCalls, isEmpty);
    });

    test('repo BackupException is surfaced as a failure message', () async {
      final repo = FakeBackupRepository(
        createBackupError: BackupStorageException('disk full'),
      );
      final service = await buildBackupService(repository: repo);
      final result = await service.createBackup();
      expect(result.success, isFalse);
      expect(result.message, contains('disk full'));
    });

    test('generic errors are reported as a generic failure', () async {
      final repo = FakeBackupRepository(createBackupError: Exception('boom'));
      final service = await buildBackupService(repository: repo);
      final result = await service.createBackup();
      expect(result.success, isFalse);
      expect(result.message, 'Could not create the backup.');
    });
  });

  group('BackupService.restore', () {
    test('requires admin', () async {
      final service = await buildBackupService(
        authService: await buildTestDataEntryAuthService(),
      );
      await expectLater(
        () => service.restore('/tmp/school_backup.db'),
        throwsA(isA<BackupPermissionException>()),
      );
    });

    test('rejects an invalid backup file', () async {
      final repo = FakeBackupRepository(
        verifyResults: [_bad('corrupt')],
      );
      final service = await buildBackupService(repository: repo);
      await expectLater(
        () => service.restore('/tmp/bad.db'),
        throwsA(isA<BackupInvalidException>()),
      );
      expect(repo.replaceLiveCalls, isEmpty);
    });

    test('rejects a newer schema version', () async {
      final repo = FakeBackupRepository(
        verifyResults: [_ok(13)],
        liveSchemaVersionResult: 12,
      );
      final service = await buildBackupService(repository: repo);
      await expectLater(
        () => service.restore('/tmp/newer.db'),
        throwsA(isA<BackupSchemaIncompatibilityException>()),
      );
    });

    test('restores a compatible backup and flags restart', () async {
      final repo = FakeBackupRepository(
        createBackupResult: testBackupRecord(
          path: '/tmp/backups/pre_restore.db',
        ),
        liveSchemaVersionResult: 12,
      );
      final service = await buildBackupService(repository: repo);

      final outcome = await service.restore('/tmp/school_backup.db');

      expect(outcome.success, isTrue);
      expect(outcome.safetyBackup, '/tmp/backups/pre_restore.db');
      expect(outcome.version, 12);
      expect(service.needsRestart, isTrue);
      expect(repo.replaceLiveCalls, isNotEmpty);
      expect(repo.replaceLiveCalls.single, '/tmp/test_live.db');
      expect(repo.copyFileCalls, isEmpty);
    });

    test('rolls back via safety backup when replace fails', () async {
      final repo = FakeBackupRepository(
        createBackupResult: testBackupRecord(
          path: '/tmp/backups/pre_restore.db',
        ),
        replaceLiveThrows: true,
        liveSchemaVersionResult: 12,
      );
      final service = await buildBackupService(repository: repo);

      await expectLater(
        () => service.restore('/tmp/school_backup.db'),
        throwsA(isA<BackupRestoreException>()),
      );
      expect(repo.copyFileCalls, isNotEmpty);
    });

    test('rolls back when the restored database fails verification', () async {
      final repo = FakeBackupRepository(
        createBackupResult: testBackupRecord(
          path: '/tmp/backups/pre_restore.db',
        ),
        liveSchemaVersionResult: 12,
        verifyResults: [_ok(12), _bad('integrity')],
      );
      final service = await buildBackupService(repository: repo);

      await expectLater(
        () => service.restore('/tmp/school_backup.db'),
        throwsA(isA<BackupRestoreException>()),
      );
      expect(repo.replaceLiveCalls, isNotEmpty);
      expect(repo.copyFileCalls, isNotEmpty);
      expect(repo.copyFileCalls.first, contains('pre_restore'));
    });
  });

  group('BackupService.reload / getters', () {
    test('populates backups and exposes the latest', () async {
      final record = testBackupRecord(path: '/tmp/backups/school_backup.db');
      final repo = FakeBackupRepository(listResult: [record]);
      final service = await buildBackupService(repository: repo);

      await service.reload();

      expect(service.backups, hasLength(1));
      expect(service.latestBackup?.path, record.path);
      expect(service.needsRestart, isFalse);
      expect(service.isAdmin, isTrue);
    });

    test('captures repository errors', () async {
      final repo = FakeBackupRepository(listBackupsThrows: true);
      final service = await buildBackupService(repository: repo);

      await service.reload();

      expect(service.error, isNotNull);
      expect(service.backups, isEmpty);
    });

    test('non-admin reports not-admin', () async {
      final service = await buildBackupService(
        authService: await buildTestDataEntryAuthService(),
      );
      expect(service.isAdmin, isFalse);
    });
  });

  group('BackupService.deleteBackup', () {
    test('admin deletes a file and reloads', () async {
      final repo = FakeBackupRepository(
        listResult: [testBackupRecord()],
        createBackupResult: testBackupRecord(),
      );
      final service = await buildBackupService(repository: repo);
      await service.reload();

      await service.deleteBackup(service.backups.first);

      expect(repo.deleteFileCalls, isNotEmpty);
    });

    test('non-admin is rejected', () async {
      final service = await buildBackupService(
        authService: await buildTestDataEntryAuthService(),
      );
      expect(
        () => service.deleteBackup(testBackupRecord()),
        throwsA(isA<BackupPermissionException>()),
      );
    });
  });

  group('BackupService.checkIntegrity and showInFolder', () {
    test('integrity_check ok on a fresh database', () async {
      final service = await buildBackupService();
      expect(await service.checkIntegrity(), isTrue);
    });

    test('showInFolder delegates to the repository', () async {
      final repo = FakeBackupRepository(openBackupLocationResult: true);
      final service = await buildBackupService(repository: repo);
      expect(await service.showInFolder(), isTrue);
      expect(repo.openBackupLocationCalls, isNotEmpty);
    });

    test('showInFolder returns false when the locator fails', () async {
      final repo = FakeBackupRepository(openBackupLocationResult: false);
      final service = await buildBackupService(repository: repo);
      expect(await service.showInFolder(), isFalse);
    });
  });
}
