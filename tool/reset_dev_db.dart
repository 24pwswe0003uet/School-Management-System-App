import 'dart:io' show Platform;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:school_management/core/database/app_database.dart';
import 'package:school_management/core/database/migrations/migrations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Determine database path
  String dbPath;
  if (Platform.isWindows) {
    final appDoc = await getApplicationSupportDirectory();
    dbPath = p.join(appDoc.path, 'school_office_management.db');
  } else {
    final appDoc = await getApplicationSupportDirectory();
    dbPath = p.join(appDoc.path, 'school_office_management.db');
  }

  print('Resetting development database at: $dbPath');

  // Check if file exists
  final exists = await File(dbPath).exists();
  if (!exists) {
    print('Database file does not exist. Creating fresh database...');
    // The database will be created fresh when the app starts
    // We just need to ensure the schema is set up correctly
    final db = await AppDatabase.open();
    await db.close();
    print('Schema is intact. No data to reset.');
    return;
  }

  // Open existing database and truncate business tables
  final database = await openDatabase(
    dbPath,
    version: AppDatabase.schemaVersion,
    onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = OFF');
    },
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );

  // Disable FK checks for truncation
  await database.execute('PRAGMA foreign_keys = OFF');

  try {
    // Truncate business tables in dependency order (children first, then parents)
    // Order matters due to foreign key constraints

    // 1. Clear data tables (children with FK to parents)
    await database.execute('DELETE FROM payments');
    await database.execute('DELETE FROM fee_records');
    await database.execute('DELETE FROM salary_records');
    await database.execute('DELETE FROM salary_payments');
    await database.execute('DELETE FROM expense_payments');
    await database.execute('DELETE FROM import_errors');
    await database.execute('DELETE FROM backup_records');

    // 2. Clear main business tables
    await database.execute('DELETE FROM users');
    await database.execute('DELETE FROM families');
    await database.execute('DELETE FROM students');
    await database.execute('DELETE FROM admissions');
    await database.execute('DELETE FROM employees');
    await database.execute('DELETE FROM expenses');

    // 3. Clear fee-related tables
    await database.execute('DELETE FROM fee_structures');
    await database.execute('DELETE FROM app_settings');
    await database.execute('DELETE FROM school_logo');

    // 4. Clear remaining tables
    await database.execute('DELETE FROM import_jobs');

    // 5. Preserve schema reference tables
    // academic_classes - seeded in migration V12, preserved
    // academic_sections - seeded in migration V12, preserved
    // schema_versions - tracks migrations, preserved

    // Re-enable FK checks
    await database.execute('PRAGMA foreign_keys = ON');

    // Verify: count remaining rows
    final classCount = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM academic_classes'),
    ) ?? 0;
    final sectionCount = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM academic_sections'),
    ) ?? 0;
    final schemaCount = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM schema_versions'),
    ) ?? 0;

    print('\n=== Reset Summary ===');
    print('academic_classes: $classCount rows (PRESERVED)');
    print('academic_sections: $sectionCount rows (PRESERVED)');
    print('schema_versions: $schemaCount rows (PRESERVED)');

    // Verify business tables are empty
    final tables = {
      'users': 'SELECT COUNT(*) FROM users',
      'families': 'SELECT COUNT(*) FROM families',
      'students': 'SELECT COUNT(*) FROM students',
      'admissions': 'SELECT COUNT(*) FROM admissions',
      'employees': 'SELECT COUNT(*) FROM employees',
      'salary_records': 'SELECT COUNT(*) FROM salary_records',
      'fee_structures': 'SELECT COUNT(*) FROM fee_structures',
      'app_settings': 'SELECT COUNT(*) FROM app_settings',
      'school_logo': 'SELECT COUNT(*) FROM school_logo',
    };

    print('\n=== Business Table Row Counts (should all be 0) ===');
    for (final entry in tables.entries) {
      final count = Sqflite.firstIntValue(
        await database.rawQuery(entry.value),
      ) ?? -1;
      print('${entry.key}: $count ${count == 0 ? '(EMPTY)' : ''}');
    }

    print('\n=== Reset Complete ===');
    print('Database schema preserved. Business data cleared.');
    print('Run the application to re-seed or populate as needed.');

  } catch (e) {
    print('Error during reset: $e');
    // Ensure FK checks are re-enabled even on error
    try {
      await database.execute('PRAGMA foreign_keys = ON');
    } catch (_) {}
  } finally {
    await database.close();
  }
}

// Helper to open database via AppDatabase pattern
Future<Database> _openDb(String path) async {
  return await openDatabase(
    path,
    version: AppDatabase.schemaVersion,
    onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = OFF');
    },
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );
}

Future<void> _onCreate(Database db, int version) async {
  await _ensureVersionsTable(db);
  for (final migration in migrations) {
    await _applyMigration(db, migration);
  }
}

Future<void> _onUpgrade(
    Database db, int oldVersion, int newVersion) async {
  await _ensureVersionsTable(db);
  for (final migration in migrations) {
    if (migration.version > oldVersion) {
      await _applyMigration(db, migration);
    }
  }
}

Future<void> _ensureVersionsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS schema_versions (
      version    INTEGER PRIMARY KEY,
      applied_at TEXT NOT NULL
    )
  ''');
}

Future<void> _applyMigration(Database db, Migration migration) async {
  for (final statement in migration.statements) {
    await db.execute(statement);
  }
  await db.insert('schema_versions', {
    'version': migration.version,
    'applied_at': DateTime.now().toUtc().toIso8601String(),
  });
}