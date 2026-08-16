import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'migrations/migration.dart';
import 'migrations/migrations.dart';

/// Owns the single SQLite connection for the application.
///
/// Uses sqflite on the FFI database factory (configured in `main`), so the
/// same code path runs on Windows desktop and in unit tests (in-memory).
class AppDatabase {
  AppDatabase._(this._database);

  final Database _database;

  static const String fileName = 'school_office_management.db';

  static int get schemaVersion => migrations.last.version;

  /// The raw sqflite handle. Repositories should use this and keep their SQL
  /// inside the repository/data layer, never in widgets.
  Database get raw => _database;

  static Future<AppDatabase> open({String? path}) async {
    final dbPath = path ?? await defaultPath();
    final database = await openDatabase(
      dbPath,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return AppDatabase._(database);
  }

  /// Default location for the database file on Windows:
  /// `%APPDATA%\com.schooloffice\school_office_management\`.
  ///
  /// On the web there is no filesystem; the WASM backend stores the database
  /// under [fileName] in the browser's IndexedDB-backed worker storage.
  static Future<String> defaultPath() async {
    if (kIsWeb) {
      // On Web, use the application support directory for IndexedDB persistence
      // This ensures the database is stored in a consistent location across sessions
      final directory = await getApplicationSupportDirectory();
      return p.join(directory.path, fileName);
    }
    final directory = await getApplicationSupportDirectory();
    return p.join(directory.path, fileName);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _ensureVersionsTable(db);
    for (final migration in migrations) {
      await _applyMigration(db, migration);
    }
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await _ensureVersionsTable(db);
    for (final migration in migrations) {
      if (migration.version > oldVersion) {
        await _applyMigration(db, migration);
      }
    }
  }

  static Future<void> _ensureVersionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schema_versions (
        version    INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL
      )
    ''');
  }

  /// sqflite runs `onCreate`/`onUpgrade` inside a transaction, so a failed
  /// migration rolls back cleanly and never leaves a half-applied schema.
  static Future<void> _applyMigration(Database db, Migration migration) async {
    for (final statement in migration.statements) {
      await db.execute(statement);
    }
    await db.insert('schema_versions', {
      'version': migration.version,
      'applied_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> close() => _database.close();
}
