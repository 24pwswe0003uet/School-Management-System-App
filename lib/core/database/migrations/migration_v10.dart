import 'migration.dart';

/// Schema version 10: extends the Module 2 `salary_records` table with the
/// fields the Salary Management module needs and enforces the one-record-per-
/// employee-month rule.
///
/// All column statements are additive. The UNIQUE index on
/// `(employee_id, period_start)` is the database backstop for the module's
/// "one salary record per employee per month" business rule; before creating it
/// any accidental duplicates are reduced to the newest row per employee+month.
/// `salary_record_id` is backfilled from the primary key so existing rows get
/// stable human-readable codes (`SAL-000001`...).
const Migration migrationV10 = Migration(
  version: 10,
  statements: [
    'ALTER TABLE salary_records ADD COLUMN salary_record_id TEXT',
    // Backfill human-readable codes for any pre-existing rows.
    "UPDATE salary_records SET salary_record_id = 'SAL-' || "
        "substr('000000' || id, -6) WHERE salary_record_id IS NULL "
        "OR salary_record_id = ''",
    // Other adjustment can be positive (bonus) or negative (fine).
    'ALTER TABLE salary_records ADD COLUMN other_adjustment REAL NOT NULL '
        'DEFAULT 0',
    'ALTER TABLE salary_records ADD COLUMN notes TEXT',
    'ALTER TABLE salary_records ADD COLUMN updated_at TEXT',
    "UPDATE salary_records SET updated_at = created_at "
        "WHERE updated_at IS NULL",
    // Keep the newest record per employee+month if duplicates ever existed.
    'DELETE FROM salary_records WHERE id NOT IN '
        '(SELECT MAX(id) FROM salary_records '
        'GROUP BY employee_id, period_start)',
    // One salary record per employee per month.
    'CREATE UNIQUE INDEX idx_salary_records_employee_period '
        'ON salary_records(employee_id, period_start)',
    'CREATE UNIQUE INDEX idx_salary_records_code '
        'ON salary_records(salary_record_id)',
    'CREATE INDEX idx_salary_records_period_start '
        'ON salary_records(period_start)',
  ],
);
