import 'package:flutter/foundation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../features/auth/domain/entities/app_role.dart';
import '../../../../features/auth/domain/services/auth_service.dart';
import '../entities/backup_record.dart';
import '../entities/backup_result.dart';
import '../entities/restore_outcome.dart';
import '../exceptions.dart';
import '../repositories/backup_repository.dart';

/// Drives the Backup & Data Management flows and exposes status to the UI.
///
/// This is the abstraction seam called for in §13: the local-only logic lives
/// here behind a simple [BackupService] interface, so a future cloud service
/// could implement the same contract. **Version 1 is local-only.**
///
/// File operations are delegated to [BackupRepository] (which owns `dart:io`),
/// so this service stays web-safe and fully unit-testable with a fake repo.
class BackupService extends ChangeNotifier {
  BackupService({
    required AppDatabase database,
    required BackupRepository repository,
    required AuthService authService,
    Future<String> Function()? liveDatabasePath,
  })  : _database = database,
        _repository = repository,
        _authService = authService,
        _liveDatabasePath = liveDatabasePath ?? AppDatabase.defaultPath;

  final AppDatabase _database;
  final BackupRepository _repository;
  final AuthService _authService;
  final Future<String> Function() _liveDatabasePath;

  List<BackupRecord> _backups = const [];
  bool _loading = false;
  Object? _error;
  bool _needsRestart = false;

  /// True once a restore has completed and the live database has been
  /// replaced. The UI must instruct the user to restart the app afterwards;
  /// the service no longer holds a usable connection to the replaced file.
  bool get needsRestart => _needsRestart;
  bool get isAdmin => _authService.currentUser?.role == AppRole.schoolAdmin;

  List<BackupRecord> get backups => _backups;
  bool get isLoading => _loading;
  Object? get error => _error;
  BackupRecord? get latestBackup =>
      _backups.isNotEmpty ? _backups.first : null;

  void _requireAdmin() {
    if (!isAdmin) throw const BackupPermissionException();
  }

  /// Loads the backup list from the backup directory.
  Future<void> reload() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _backups = await _repository.listBackups();
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Creates a verified backup. Throws [BackupPermissionException] for
  /// non-admins (surfacing as a failure result for the UI to display).
  Future<BackupResult> createBackup() async {
    try {
      _requireAdmin();
    } on BackupPermissionException catch (e) {
      _error = e;
      notifyListeners();
      return BackupResult.failure(e.message);
    }

    _error = null;
    notifyListeners();
    final when = DateTime.now();
    final targetPath = await _repository.nextBackupPath(when);
    try {
      final record = await _repository.createBackup(
        database: _database.raw,
        targetPath: targetPath,
      );
      await reload();
      return BackupResult.success(record);
    } on BackupException catch (e) {
      _error = e;
      notifyListeners();
      return BackupResult.failure(e.message);
    } catch (e) {
      _error = e;
      notifyListeners();
      return BackupResult.failure('Could not create the backup.');
    }
  }

  /// Full restore orchestration. Throws on any unsafe condition; only the file
  /// is replaced after a successful safety backup + close. Throws
  /// [BackupPermissionException] for non-admins too. After a successful restore
  /// the user must restart the app.
  Future<RestoreOutcome> restore(String backupPath) async {
    _requireAdmin();
    _error = null;
    notifyListeners();

    // 1. Validate the selected backup is a readable database.
    final verification = await _repository.verifyAt(backupPath);
    if (!verification.isOk) {
      throw const BackupInvalidException('');
    }

    // 2. Schema compatibility (§11): never restore a newer schema over the live
    //    database (would silently lose data).
    final currentVersion = await _repository.liveSchemaVersion(_database.raw);
    if (verification.schemaVersion > currentVersion) {
      throw BackupSchemaIncompatibilityException(
        verification.schemaVersion,
        currentVersion,
      );
    }

    // 3. Safety backup while the live database is still open & available (§9).
    final safetyPath = await _repository.nextSafetyBackupPath(DateTime.now());
    final safetyRecord = await _repository.createBackup(
      database: _database.raw,
      targetPath: safetyPath,
    );

    // 4. Close the live connection so the file can be replaced.
    try {
      await _database.close();
    } catch (e) {
      throw BackupRestoreException('The database could not be closed: $e');
    }

    final livePath = await _liveDatabasePath();

     // 5. Replace the live file atomically; clean up sidecars first.
    try {
      await _repository.replaceLiveDatabase(
        livePath: livePath,
        backupPath: backupPath,
      );
    } catch (e) {
      // The original data was preserved on disk by design (we delete then
      // copy); if the copy failed, recover from the safety backup.
      await _repository.copyFile(safetyRecord.path, livePath);
      throw BackupRestoreException('Could not replace the database file: $e');
    }

    // 6. Verify the replaced live database (§18) — if it isn't valid, roll back
    //    to the safety backup so the app can boot.
    final liveVerification = await _repository.verifyAt(livePath);
    if (!liveVerification.isOk) {
      await _repository.copyFile(safetyRecord.path, livePath);
      throw const BackupRestoreException(
        'The restored database failed verification and could not be read.',
      );
    }

    // 7. The connection is now closed/replaced; the app must restart to reopen
    //    every repository with the new file.
    _needsRestart = true;
    _error = null;
    notifyListeners();
    return RestoreOutcome.success(
      safetyBackup: safetyRecord.path,
      version: liveVerification.schemaVersion,
    );
  }

  /// Runs `PRAGMA integrity_check` against the live database.
  Future<bool> checkIntegrity() async {
    try {
      final rows =
          await _database.raw.rawQuery('PRAGMA integrity_check');
      final value = rows.isNotEmpty ? rows.first.values.first : 'unknown';
      notifyListeners();
      return '$value' == 'ok';
    } catch (e) {
      _error = e;
      notifyListeners();
      return false;
    }
  }

  /// Reveals the backup directory in the native file manager ("Show in folder").
  Future<bool> showInFolder() => _repository.openBackupLocation();

  /// Deletes a backup file. Admin-only; the module never deletes automatically.
  Future<void> deleteBackup(BackupRecord record) async {
    _requireAdmin();
    await _repository.deleteFile(record.path);
    await reload();
  }

  @override
  void dispose() {
    _error = null;
    super.dispose();
  }
}
