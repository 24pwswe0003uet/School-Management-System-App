import 'package:sqflite/sqflite.dart';

import '../entities/backup_record.dart';
import '../entities/backup_verification.dart';

/// Data operations for the Backup & Data Management module.
///
/// The implementation is SQLite-aware: backups are produced with `VACUUM INTO`
/// (an engine-consistent snapshot taken while the live database stays open),
/// and every file is verified by opening it **read-only** before it is trusted.
///
/// High-level restore orchestration lives in [BackupService], which owns the
/// live database lifecycle (it is the only caller that can close & reopen the
/// app's shared connection). This keeps data-safety logic in one place.
abstract interface class BackupRepository {
  /// Stable directory where backup files are kept.
  String get backupDirectory;

  /// Lists every `school_backup_*.db` in the backup directory, newest first.
  /// Existence and readability are re-checked on each call; status is a light
  /// check (full integrity verification is run on demand).
  Future<List<BackupRecord>> listBackups();

  /// Builds a backup filename for [when], guaranteed unique on disk.
  Future<String> nextBackupPath(DateTime when);

  /// Builds a unique safety-backup filename for [when].
  Future<String> nextSafetyBackupPath(DateTime when);

  /// A consistent snapshot of [database] into [targetPath] via `VACUUM INTO`,
  /// followed by verification. Throws if the snapshot or verification fails;
  /// any partially written file is cleaned up.
  Future<BackupRecord> createBackup({
    required Database database,
    required String targetPath,
  });

  /// `PRAGMA user_version` of the open database = current schema version.
  Future<int> liveSchemaVersion(Database database);

  /// Read-only verification of any SQLite file: existence, size, readability,
  /// `PRAGMA integrity_check`, required tables, and schema version. Opens the
  /// file read-only with no upgrade so it is never altered.
  Future<BackupVerification> verifyAt(String path);

  /// Replaces the live database file at [livePath] with the contents of
  /// [backupPath]. **The caller must have closed the live database first.**
  /// Stale WAL/SHM/journal files are removed; the copy is fsynced.
  Future<void> replaceLiveDatabase({
    required String livePath,
    required String backupPath,
  });

  /// Best-effort recovery: copies [safetyPath] over [livePath] (the live file
  /// must have already been removed by the caller). Used if a restore failed
  /// after the live file was deleted.
  Future<void> copyFile(String from, String to);

  /// Reveals the backup directory in the native file manager ("Show in folder").
  Future<bool> openBackupLocation();

  /// Deletes a single backup or temp file (no-op if missing). The UI calls this
  /// only on explicit user confirmation; the module never auto-deletes.
  Future<void> deleteFile(String path);
}
