import 'migration.dart';

/// Schema version 13: adds fee_type to fee_structures to distinguish
/// admission (one-time) from monthly (recurring) fee rules.
///
/// Existing rows are classified based on their name:
///   - names containing "admission" (case-insensitive) → fee_type = 'admission'
///   - all other existing rules → fee_type = 'monthly' (default)
const Migration migrationV13 = Migration(
  version: 13,
  statements: [
    // Add fee_type column — 'admission' or 'monthly'.
    // Existing rows are classified below; new rows default to 'monthly'.
    'ALTER TABLE fee_structures ADD COLUMN fee_type TEXT NOT NULL DEFAULT "monthly"',

    // Classify existing rules based on their name.
    // This runs as a raw UPDATE inside a transaction-like pattern via the
    // migration runner (each statement is executed once on upgrade).
    "UPDATE fee_structures SET fee_type = 'admission' "
        "WHERE LOWER(name) LIKE '%admission%'",

    // All remaining rows keep the default 'monthly'; no further UPDATE needed.
  ],
);