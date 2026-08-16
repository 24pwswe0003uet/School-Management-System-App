import 'migration.dart';

/// Schema version 14: fixes fee_structures uniqueness to (class_name, fee_type).
///
/// Allows one Admission rule and one Monthly rule per class (including NULL class for defaults).
/// Drops the old single-column unique index and the partial default index.
/// For NULL class_name (defaults), we need a partial index because SQLite treats
/// NULL as distinct in unique indexes. So we create a partial index on a constant
/// expression per fee_type for the default case.
const Migration migrationV14 = Migration(
  version: 14,
  statements: [
    // Drop old indexes
    'DROP INDEX IF EXISTS idx_fee_structures_class',
    'DROP INDEX IF EXISTS idx_fee_structures_default',

    // New composite unique index: one rule per (class_name, fee_type) for non-NULL classes
    'CREATE UNIQUE INDEX idx_fee_structures_class_type '
        'ON fee_structures(class_name, fee_type) WHERE class_name IS NOT NULL',

    // Partial unique indexes for default rules (class_name IS NULL)
    // One default Admission rule, one default Monthly rule
    'CREATE UNIQUE INDEX idx_fee_structures_default_admission '
        'ON fee_structures((1)) WHERE class_name IS NULL AND fee_type = \'admission\'',
    'CREATE UNIQUE INDEX idx_fee_structures_default_monthly '
        'ON fee_structures((1)) WHERE class_name IS NULL AND fee_type = \'monthly\'',
  ],
);