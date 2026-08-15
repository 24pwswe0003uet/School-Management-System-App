import 'migration.dart';

/// Schema version 11: extends the Module 2 `expenses` table with the fields the
/// Expense Management module needs — an optional reference, the created-by audit
/// trail and an updated timestamp.
///
/// All statements are additive so existing databases upgrade in place. The
/// category column stays open TEXT (validated in Dart) so categories can extend
/// over time without another migration, following the employees.category
/// precedent from v9. `expense_id` is backfilled from the primary key so any
/// legacy rows get stable human-readable codes (`EXP-000001`...).
const Migration migrationV11 = Migration(
  version: 11,
  statements: [
    // Optional vendor reference (e.g. a bill or invoice number).
    'ALTER TABLE expenses ADD COLUMN reference TEXT',
    // Who recorded the expense (the signed-in user's display name).
    'ALTER TABLE expenses ADD COLUMN created_by TEXT',
    'ALTER TABLE expenses ADD COLUMN updated_at TEXT',
    "UPDATE expenses SET updated_at = created_at "
        "WHERE updated_at IS NULL",
    // Backfill human-readable codes for any pre-existing rows. The column is
    // already NOT NULL UNIQUE from v2, so only empty strings need a code.
    "UPDATE expenses SET expense_id = 'EXP-' || "
        "substr('000000' || id, -6) WHERE expense_id = ''",
    // Category totals/reports filter on this column.
    'CREATE INDEX idx_expenses_category ON expenses(category)',
  ],
);
