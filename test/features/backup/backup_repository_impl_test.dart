import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:school_office_management/core/database/app_database.dart';
import 'package:school_office_management/core/database/database_factory.dart';
import 'package:school_office_management/features/backup/data/repositories/backup_repository_impl.dart';
import 'package:school_office_management/features/backup/domain/entities/backup_record.dart';

import 'package:school_office_management/features/backup/domain/exceptions.dart';
import 'package:sqflite/sqflite.dart';

Future<AppDatabase> _openTestDb() async {
  initDatabaseFactory();
  return AppDatabase.open(path: inMemoryDatabasePath);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late BackupRepositoryImpl repo;
  late AppDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_repo_test');
    repo = BackupRepositoryImpl(backupDirectory: tempDir.path);
    db = await _openTestDb();
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('nextBackupPath / nextSafetyBackupPath are unique and prefixed', () async {
    final when = DateTime(2026, 8, 15, 10, 5, 0);
    final backup = await repo.nextBackupPath(when);
    final safety = await repo.nextSafetyBackupPath(when);

    expect(backup, endsWith('.db'));
    expect(p.basename(backup), startsWith('school_backup_'));
    expect(p.basename(safety), startsWith('pre_restore_backup_'));
    expect(p.isAbsolute(backup), isTrue);

    final second = await repo.nextBackupPath(
      DateTime(2026, 8, 15, 10, 5, 1),
    );
    expect(second, isNot(backup));
  });

  test('createBackup produces a verified file with the live schema version',
      () async {
    final target = p.join(tempDir.path, 'school_backup_test.db');
    final record = await repo.createBackup(database: db.raw, targetPath: target);

    final file = File(target);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(0));
    expect(record.schemaVersion, 12);
    expect(record.status, BackupStatus.successful);
  });

  test('verifyAt validates a real backup file', () async {
    final target = p.join(tempDir.path, 'school_backup_verify.db');
    final record = await repo.createBackup(database: db.raw, targetPath: target);

    final verification = await repo.verifyAt(target);
    expect(verification.isOk, isTrue);
    expect(verification.schemaVersion, record.schemaVersion);
    expect(verification.tablesPresent, isTrue);
    expect(verification.sizeBytes, greaterThan(0));
  });

  test('verifyAt flags a missing file', () async {
    final verification =
        await repo.verifyAt(p.join(tempDir.path, 'missing.db'));
    expect(verification.isOk, isFalse);
    expect(verification.exists, isFalse);
    expect(verification.errorMessage, contains('not found'));
  });

  test('verifyAt flags an empty file', () async {
    final empty = p.join(tempDir.path, 'school_backup_empty.db');
    File(empty).createSync();
    final verification = await repo.verifyAt(empty);
    expect(verification.isOk, isFalse);
    expect(verification.exists, isTrue);
    expect(verification.sizeBytes, 0);
  });

  test('verifyAt flags a non-database file', () async {
    final notDb = p.join(tempDir.path, 'school_backup_text.db');
    await File(notDb).writeAsString('not a database');
    final verification = await repo.verifyAt(notDb);
    expect(verification.isOk, isFalse);
    expect(verification.readable, isFalse);
    expect(verification.errorMessage, isNotNull);
  });

  test('listBackups returns only backup files, newest first', () async {
    final dir = Directory(tempDir.path);
    await File(p.join(dir.path, 'school_backup_2026-01-01_000000.db')).writeAsString('x');
    await File(p.join(dir.path, 'school_backup_2026-02-02_000000.db')).writeAsString('x');
    await File(p.join(dir.path, 'not_a_backup.txt')).writeAsString('x');

    final backups = await repo.listBackups();
    expect(backups, hasLength(2));
    expect(backups[0].createdAt.isAfter(backups[1].createdAt), isTrue);
  });

  test('deleteFile removes the file and is a no-op for missing files', () async {
    final target = p.join(tempDir.path, 'school_backup_del.db');
    await File(target).writeAsString('x');
    await repo.deleteFile(target);
    expect(File(target).existsSync(), isFalse);

    await repo.deleteFile(p.join(tempDir.path, 'nope.db'));
  });

  test('replaceLiveDatabase replaces the live file and clears sidecars', () async {
    final live = p.join(tempDir.path, 'live.db');
    final backup = p.join(tempDir.path, 'school_backup_src.db');
    await File(live).writeAsString('OLD');
    await File('$live.wal').writeAsString('wal');
    await File('$live.shm').writeAsString('shm');
    await File('$backup').writeAsString('NEW');

    await repo.replaceLiveDatabase(livePath: live, backupPath: backup);

    expect(File('$live.wal').existsSync(), isFalse);
    expect(File('$live.shm').existsSync(), isFalse);
    expect(File(live).readAsStringSync(), 'NEW');
  });

  test('copyFile duplicates content and fsyncs', () async {
    final from = p.join(tempDir.path, 'school_backup_src.db');
    final to = p.join(tempDir.path, 'copied.db');
    await File(from).writeAsString('DATA');
    await repo.copyFile(from, to);
    expect(File(to).readAsStringSync(), 'DATA');
  });

  test('createBackup cleans up an unverifiable file', () async {
    // A fresh database created without migrations lacks the required tables,
    // so VACUUM INTO produces a file that fails table verification.
    final rawFile = File(p.join(tempDir.path, 'raw_empty.db'));
    final raw = await openDatabase(rawFile.path);
    final target = p.join(tempDir.path, 'school_backup_invalid.db');
    try {
      await repo.createBackup(database: raw, targetPath: target);
      fail('expected a BackupException');
    } on BackupException catch (e) {
      expect(e.message, contains('verified'));
    } finally {
      await raw.close();
    }
    expect(File(target).existsSync(), isFalse);
  });
}
