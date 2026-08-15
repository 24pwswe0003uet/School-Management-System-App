import 'migration.dart';

/// Schema version 1: authentication (`users` table).
const Migration migrationV1 = Migration(
  version: 1,
  statements: [
    '''
    CREATE TABLE users (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      username      TEXT NOT NULL COLLATE NOCASE UNIQUE,
      password_hash TEXT NOT NULL,
      display_name  TEXT NOT NULL,
      role          TEXT NOT NULL CHECK (role IN ('school_admin', 'data_entry')),
      is_active     INTEGER NOT NULL DEFAULT 1,
      created_at    TEXT NOT NULL,
      updated_at    TEXT NOT NULL
    )
    ''',
  ],
);
