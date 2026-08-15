import 'migration.dart';

/// Schema version 8: repairs the "one default fee rule" constraint.
///
/// The v7 index `idx_fee_structures_default` was defined over the nullable
/// `class_name` column with `WHERE class_name IS NULL`. SQLite treats NULLs as
/// distinct in unique indexes, so a second global default rule (also NULL) was
/// never rejected. Rebuilding the index over the constant expression `1` gives
/// every default row the same non-NULL key, so the uniqueness actually fires.
const Migration migrationV8 = Migration(
  version: 8,
  statements: [
    'DROP INDEX IF EXISTS idx_fee_structures_default',
    'CREATE UNIQUE INDEX idx_fee_structures_default '
        'ON fee_structures((1)) WHERE class_name IS NULL',
  ],
);
