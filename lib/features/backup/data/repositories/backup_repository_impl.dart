import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/backup_record.dart';
import '../../domain/entities/backup_verification.dart';
import '../../domain/exceptions.dart';
import '../../domain/repositories/backup_repository.dart';

/// Tables a backup must contain to be considered a valid school database.
const List<String> _requiredTables = [
  'users',
  'families',
  'students',
  'admissions',
  'employees',
  'fee_records',
  'payments',
  'salary_records',
  'expenses',
  'app_settings',
  'custom_field_definitions',
  'custom_field_values',
  'schema_versions',
];

/// SQLite-backed [BackupRepository]. Uses `VACUUM INTO` for snapshots and a
/// read-only connection for verification so the live database is never altered
/// while checking. File operations are confined to this data layer (no `dart:io`
/// leaks into the domain/service layer), so the service stays web-safe.
class BackupRepositoryImpl implements BackupRepository {
  BackupRepositoryImpl({
    required this.backupDirectory,
    this.backupFilePrefix = 'school_backup',
  });

  @override
  final String backupDirectory;
  final String backupFilePrefix;

  String get _filePrefix => '${backupFilePrefix}_';

  @override
  Future<List<BackupRecord>> listBackups() async {
    final dir = Directory(backupDirectory);
    if (!await dir.exists()) {
      return const [];
    }
    final files = <BackupRecord>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith(_filePrefix) || !name.endsWith('.db')) {
        continue;
      }
      final createdAt = _parseTimestamp(name);
      if (createdAt == null) continue;
      final size = await entity.length();
      final readable = size > 0 && await _isReadable(entity.path);
      files.add(
        BackupRecord(
          path: entity.path,
          createdAt: createdAt,
          sizeBytes: size,
          schemaVersion: 0,
          status: readable ? BackupStatus.successful : BackupStatus.failed,
        ),
      );
    }
    files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return files;
  }

  @override
  Future<String> nextBackupPath(DateTime when) =>
      _uniquePath(when, _filePrefix);

  @override
  Future<String> nextSafetyBackupPath(DateTime when) =>
      _uniquePath(when, 'pre_restore_backup_');

  Future<String> _uniquePath(DateTime when, String prefix) async {
    final stamp = _stamp(when);
    final dir = Directory(backupDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    var path = p.join(dir.path, '$prefix$stamp.db');
    var suffix = 1;
    while (await File(path).exists()) {
      path = p.join(dir.path, '$prefix$stamp$suffix.db');
      suffix++;
    }
    return path;
  }

  @override
  Future<BackupRecord> createBackup({
    required Database database,
    required String targetPath,
  }) async {
    final escaped = _escapeLiteral(targetPath);
    // VACUUM INTO writes a transactionally consistent copy of the live database
    // without copying the file by hand and without closing the connection.
    try {
      await database.rawQuery("VACUUM INTO '$escaped'");
    } catch (e) {
      _deleteIfExists(targetPath);
      throw BackupStorageException('The snapshot could not be written: $e');
    }

    final targetFile = File(targetPath);
    if (!await targetFile.exists()) {
      throw const BackupStorageException('The backup file was not created.');
    }
    final size = await targetFile.length();
    if (size == 0) {
      _deleteIfExists(targetPath);
      throw const BackupStorageException('The backup file is empty.');
    }

    final verification = await verifyAt(targetPath);
    if (!verification.isOk) {
      // Never leave an unverified file behind.
      try {
        await targetFile.delete(recursive: false);
      } catch (_) {}
      throw BackupException(
        'Backup could not be verified. '
        '${verification.errorMessage ?? ''}'.trim(),
      );
    }
    final createdAt =
        _parseTimestamp(p.basename(targetPath)) ?? DateTime.now();
    return BackupRecord(
      path: targetPath,
      createdAt: createdAt,
      sizeBytes: size,
      schemaVersion: verification.schemaVersion,
      status: BackupStatus.successful,
    );
  }

  @override
  Future<int> liveSchemaVersion(Database database) async {
    final rows = await database.rawQuery('PRAGMA user_version');
    final value = rows.first['user_version'];
    return value is int ? value : int.tryParse('$value') ?? 0;
  }

  @override
  Future<BackupVerification> verifyAt(String path) async {
    final file = File(path);
    final exists = await file.exists();
    if (!exists) {
      return const BackupVerification(
        exists: false,
        sizeBytes: 0,
        readable: false,
        integrityOk: false,
        tablesPresent: false,
        schemaVersion: 0,
        errorMessage: 'File not found.',
      );
    }
    final size = await file.length();
    if (size == 0) {
      return const BackupVerification(
        exists: true,
        sizeBytes: 0,
        readable: false,
        integrityOk: false,
        tablesPresent: false,
        schemaVersion: 0,
        errorMessage: 'Backup file is empty.',
      );
    }
    Database? db;
    try {
      db = await openDatabase(
        path,
        readOnly: true,
        singleInstance: true,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = OFF');
        },
      );
      final integrity = await _checkIntegrity(db);
      if (integrity != 'ok') {
        return BackupVerification(
          exists: true,
          sizeBytes: size,
          readable: true,
          integrityOk: false,
          tablesPresent: false,
          schemaVersion: 0,
          errorMessage: 'Integrity check failed: $integrity',
        );
      }
      final version = await _userVersion(db);
      final tablesOk = await _hasRequiredTables(db);
      return BackupVerification(
        exists: true,
        sizeBytes: size,
        readable: true,
        integrityOk: true,
        tablesPresent: tablesOk,
        schemaVersion: version,
      );
    } on DatabaseException catch (e) {
      return BackupVerification(
        exists: true,
        sizeBytes: size,
        readable: false,
        integrityOk: false,
        tablesPresent: false,
        schemaVersion: 0,
        errorMessage: 'File could not be opened as a database: $e',
      );
    } catch (e) {
      return BackupVerification(
        exists: true,
        sizeBytes: size,
        readable: false,
        integrityOk: false,
        tablesPresent: false,
        schemaVersion: 0,
        errorMessage: 'Verification error: $e',
      );
    } finally {
      await db?.close();
    }
  }

  /// Replaces the live database file at [livePath] with the contents of
  /// [backupPath]. **The caller must have closed the live database first.**
  /// Stale WAL/SHM/journal files are removed; the copy is fsynced.
  @override
  Future<void> replaceLiveDatabase({
    required String livePath,
    required String backupPath,
  }) async {
    final live = File(livePath);
    for (final suffix in ['.wal', '.shm', '.journal']) {
      final sidecar = File(livePath + suffix);
      await _deleteIfExists(sidecar.path);
    }
    await _deleteIfExists(live.path);
    await File(backupPath).copy(livePath);
    final raf = live.openSync(mode: FileMode.append);
    await raf.flush();
    await raf.close();
  }

  /// Best-effort recovery copy used by the service when a restore fails after
  /// the live file was already removed.
  @override
  Future<void> copyFile(String from, String to) async {
    final source = File(from);
    if (!await source.exists()) {
      throw BackupStorageException('Source file not found: $from');
    }
    final target = File(to);
    await target.create(recursive: true);
    await source.copy(to);
    final raf = target.openSync(mode: FileMode.append);
    await raf.flush();
    await raf.close();
  }

  @override
  Future<bool> openBackupLocation() async {
    final dir = Directory(backupDirectory);
    if (!await dir.exists()) return false;
    final String command;
    switch (Platform.operatingSystem) {
      case 'windows':
        command = 'explorer.exe';
      case 'macos':
        command = 'open';
      case 'linux':
        command = 'xdg-open';
      default:
        return false;
    }
    try {
      await Process.run(command, [dir.path]);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> deleteFile(String path) async {
    await _deleteIfExists(path);
  }

  Future<String> _checkIntegrity(Database db) async {
    final rows = await db.rawQuery('PRAGMA integrity_check');
    if (rows.isEmpty) return 'ok';
    final value = rows.first.values.first;
    return '$value';
  }

  Future<int> _userVersion(Database db) async {
    final rows = await db.rawQuery('PRAGMA user_version');
    final value = rows.first['user_version'];
    return value is int ? value : int.tryParse('$value') ?? 0;
  }

  Future<bool> _hasRequiredTables(Database db) async {
    final rows = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table'",
    );
    final names =
        rows.map((r) => (r['name'] as String).toLowerCase()).toSet();
    return _requiredTables.every(names.contains);
  }

  Future<bool> _isReadable(String path) async {
    Database? db;
    try {
      db = await openDatabase(
        path,
        readOnly: true,
        singleInstance: true,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = OFF');
        },
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      await db?.close();
    }
  }

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      try {
        await file.delete(recursive: false);
      } catch (_) {}
    }
  }

  static String _escapeLiteral(String value) =>
      value.replaceAll("'", "''");

  static String _stamp(DateTime when) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${when.year}-${two(when.month)}-${two(when.day)}'
        '_${two(when.hour)}${two(when.minute)}${two(when.second)}';
  }

  static DateTime? _parseTimestamp(String filename) {
    final match = RegExp(r'(\d{4})-(\d{2})-(\d{2})_(\d{2})(\d{2})(\d{2})')
        .firstMatch(filename);
    if (match == null) return null;
    final y = int.parse(match[1]!);
    final m = int.parse(match[2]!);
    final d = int.parse(match[3]!);
    final h = int.parse(match[4]!);
    final mi = int.parse(match[5]!);
    final s = int.parse(match[6]!);
    return DateTime(y, m, d, h, mi, s);
  }
}
