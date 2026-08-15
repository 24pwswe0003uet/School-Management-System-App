import 'migration.dart';

/// Schema version 6: the Custom Fields architecture backing the Excel import
/// module. Unknown columns from an imported workbook are never rejected or
/// shoehorned into existing tables — they become typed definitions stored in
/// `custom_field_definitions`, with their per-record values in
/// `custom_field_values`.
///
/// All statements are additive so existing databases upgrade in place.
const Migration migrationV6 = Migration(
  version: 6,
  statements: [
    '''
    CREATE TABLE custom_field_definitions (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      definition_id TEXT NOT NULL UNIQUE,
      entity_type   TEXT NOT NULL
                    CHECK (entity_type IN ('student', 'family')),
      field_name    TEXT NOT NULL,
      display_name  TEXT NOT NULL,
      data_type     TEXT NOT NULL
                    CHECK (data_type IN ('text', 'number', 'decimal', 'date', 'boolean')),
      is_active     INTEGER NOT NULL DEFAULT 1,
      created_at    TEXT NOT NULL,
      updated_at    TEXT NOT NULL,
      UNIQUE (entity_type, field_name)
    )
    ''',
    '''
    CREATE TABLE custom_field_values (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      definition_id INTEGER NOT NULL
                    REFERENCES custom_field_definitions(id) ON DELETE CASCADE,
      entity_type   TEXT NOT NULL,
      entity_id     INTEGER NOT NULL,
      value         TEXT,
      created_at    TEXT NOT NULL,
      updated_at    TEXT NOT NULL,
      UNIQUE (definition_id, entity_id)
    )
    ''',
    'CREATE INDEX idx_custom_field_defs_entity '
        'ON custom_field_definitions(entity_type, is_active)',
    'CREATE INDEX idx_custom_field_values_entity '
        'ON custom_field_values(entity_type, entity_id)',
  ],
);
