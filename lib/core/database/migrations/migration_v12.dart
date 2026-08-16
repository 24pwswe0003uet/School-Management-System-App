import 'migration.dart';

/// Schema version 12: the School Settings module.
///
/// Adds a small key-value settings table for the school profile and receipt
/// configuration, canonical class/section lists (seeded with the defaults the
/// rest of the app previously hard-coded), and a single-row BLOB table used as
/// the web fallback for the school logo (Windows stores the logo as a file in
/// the application-support directory instead).
///
/// All statements are additive so existing databases upgrade in place.
const Migration migrationV12 = Migration(
  version: 12,
  statements: [
    // Key-value settings: school_name, address, phone, email, academic_year,
    // receipt_footer, logo_kind('file'|'blob'), logo_file_name, logo_mime_type.
    '''
    CREATE TABLE app_settings (
      key        TEXT PRIMARY KEY,
      value      TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    // Canonical academic classes. Historical student rows keep their own
    // free-text class, so entries are deactivated rather than deleted.
    '''
    CREATE TABLE academic_classes (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      class_name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      is_active  INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    // Canonical academic sections (global list, V1).
    '''
    CREATE TABLE academic_sections (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      section_name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      is_active    INTEGER NOT NULL DEFAULT 1,
      created_at   TEXT NOT NULL,
      updated_at   TEXT NOT NULL
    )
    ''',
    // Web fallback for the school logo (single row, replaced on save).
    '''
    CREATE TABLE school_logo (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      mime_type  TEXT NOT NULL,
      data       BLOB NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    // Seed the default class list (previously hard-coded in report filters).
    "INSERT INTO academic_classes (class_name, is_active, created_at, updated_at) "
        "VALUES ('Play Group', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_classes (class_name, is_active, created_at, updated_at) "
        "VALUES ('Nursery', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_classes (class_name, is_active, created_at, updated_at) "
        "VALUES ('KG', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_classes (class_name, is_active, created_at, updated_at) "
        "VALUES ('1', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_classes (class_name, is_active, created_at, updated_at) "
        "VALUES ('2', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_classes (class_name, is_active, created_at, updated_at) "
        "VALUES ('3', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_classes (class_name, is_active, created_at, updated_at) "
        "VALUES ('4', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_classes (class_name, is_active, created_at, updated_at) "
        "VALUES ('5', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_classes (class_name, is_active, created_at, updated_at) "
        "VALUES ('6', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_classes (class_name, is_active, created_at, updated_at) "
        "VALUES ('7', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_classes (class_name, is_active, created_at, updated_at) "
        "VALUES ('8', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_classes (class_name, is_active, created_at, updated_at) "
        "VALUES ('9', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_classes (class_name, is_active, created_at, updated_at) "
        "VALUES ('10', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_classes (class_name, is_active, created_at, updated_at) "
        "VALUES ('11', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_classes (class_name, is_active, created_at, updated_at) "
        "VALUES ('12', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    // Seed the default section list.
    "INSERT INTO academic_sections (section_name, is_active, created_at, updated_at) "
        "VALUES ('A', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_sections (section_name, is_active, created_at, updated_at) "
        "VALUES ('B', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
    "INSERT INTO academic_sections (section_name, is_active, created_at, updated_at) "
        "VALUES ('C', 1, '1970-01-01T00:00:00', '1970-01-01T00:00:00')",
  ],
);
