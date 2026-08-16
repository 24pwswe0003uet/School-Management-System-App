import 'package:school_office_management/features/backup/domain/entities/backup_record.dart';
import 'package:school_office_management/features/backup/domain/entities/backup_verification.dart';
import 'package:school_office_management/features/backup/domain/exceptions.dart';
import 'package:school_office_management/features/backup/domain/repositories/backup_repository.dart';
import 'package:sqflite/sqflite.dart';

/// Records the calls the [BackupService] makes and lets tests script the
/// repository's responses. No filesystem or SQLite access is required to drive
/// the restore orchestration with this fake.
class FakeBackupRepository implements BackupRepository {
  FakeBackupRepository({
    this.backupDirectory = '/tmp/backups',
    this.listResult = const [],
    this.verifyResult,
    this.verifyResults = const [],
    this.liveSchemaVersionResult = 12,
    this.createBackupResult,
    this.createBackupError,
    this.replaceLiveThrows = false,
    this.copyFileThrows = false,
    this.openBackupLocationResult = true,
    this.deleteFileThrows = false,
    this.listBackupsThrows = false,
  });

  @override
  final String backupDirectory;

  final List<BackupRecord> listResult;
  final bool listBackupsThrows;
  final List<BackupRecord> listBackupsCalls = [];
  final List<String> nextBackupPathCalls = [];
  final List<String> nextSafetyBackupPathCalls = [];
  final List<_CreateBackupCall> createBackupCalls = []; // ignore: library_private_types_in_public_api
  final List<String> verifyAtCalls = [];
  final List<String> replaceLiveCalls = [];
  final List<String> deleteFileCalls = [];
  final List<String> copyFileCalls = [];
  final List<String> openBackupLocationCalls = [];
  final List<BackupRecord> deleteBackupCalls = [];

  /// Ordered verifications returned by [verifyAt]. When non-empty, each call
  /// consumes the next entry; otherwise a passing verification is returned.
  final List<BackupVerification> verifyResults;

  final BackupVerification? verifyResult;
  final int liveSchemaVersionResult;
  final BackupRecord? createBackupResult;
  final Exception? createBackupError;
  final bool replaceLiveThrows;
  final bool copyFileThrows;
  final bool openBackupLocationResult;
  final bool deleteFileThrows;

  @override
  Future<List<BackupRecord>> listBackups() async {
    listBackupsCalls.addAll(listResult);
    if (listBackupsThrows) {
      throw BackupException('listBackups failed');
    }
    return listResult;
  }

  @override
  Future<String> nextBackupPath(DateTime when) async {
    nextBackupPathCalls.add(when.toString());
    return '$backupDirectory/school_backup_${when.millisecondsSinceEpoch}.db';
  }

  @override
  Future<String> nextSafetyBackupPath(DateTime when) async {
    nextSafetyBackupPathCalls.add(when.toString());
    return '$backupDirectory/pre_restore_backup_${when.millisecondsSinceEpoch}.db';
  }

  @override
  Future<BackupRecord> createBackup({
    required Database database,
    required String targetPath,
  }) async {
    createBackupCalls.add(_CreateBackupCall(targetPath));
    if (createBackupError != null) throw createBackupError!;
    final result = createBackupResult;
    if (result == null) {
      throw BackupException('createBackup not configured');
    }
    return result;
  }

  @override
  Future<int> liveSchemaVersion(Database database) async =>
      liveSchemaVersionResult;

  @override
  Future<BackupVerification> verifyAt(String path) async {
    verifyAtCalls.add(path);
    if (verifyResults.isNotEmpty) return verifyResults.removeAt(0);
    final override = verifyResult;
    if (override != null) return override;
    return BackupVerification(
      exists: true,
      sizeBytes: 1024,
      readable: true,
      integrityOk: true,
      tablesPresent: true,
      schemaVersion: liveSchemaVersionResult,
    );
  }

  @override
  Future<void> replaceLiveDatabase({
    required String livePath,
    required String backupPath,
  }) async {
    replaceLiveCalls.add(livePath);
    if (replaceLiveThrows) {
      throw BackupStorageException('replace failed');
    }
  }

  @override
  Future<void> copyFile(String from, String to) async {
    copyFileCalls.add('$from->to');
    if (copyFileThrows) {
      throw BackupStorageException('copy failed');
    }
  }

  @override
  Future<bool> openBackupLocation() async {
    openBackupLocationCalls.add(backupDirectory);
    return openBackupLocationResult;
  }

  @override
  Future<void> deleteFile(String path) async {
    deleteFileCalls.add(path);
    if (deleteFileThrows) {
      throw BackupStorageException('delete failed');
    }
  }
}

class _CreateBackupCall {
  _CreateBackupCall(this.targetPath);
  final String targetPath;
}
