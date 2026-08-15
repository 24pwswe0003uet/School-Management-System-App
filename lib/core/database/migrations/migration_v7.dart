import 'migration.dart';

/// Schema version 7: the Fee Management module.
///
/// The Module 2 `fee_records` and `payments` tables already separated the
/// per-student charge from the payment transaction; this migration adds the
/// remaining fee fields (discount, fine, net payable, running balances),
/// payment attribution (note, created by) and the controlled reversal fields.
/// It also introduces the `fee_structures` rule table that "Generate monthly
/// fee" resolves against (one rule per class plus one global default).
///
/// All statements are additive so existing databases upgrade in place.
/// Balances and statuses are never derived here — the Fee repository updates
/// them transactionally whenever a payment is recorded, reversed, or a record
/// is adjusted.
const Migration migrationV7 = Migration(
  version: 7,
  statements: [
    // Fee structure/rules. class_name NULL is the global default rule.
    '''
    CREATE TABLE fee_structures (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      structure_id    TEXT NOT NULL UNIQUE,
      name            TEXT NOT NULL,
      description     TEXT,
      class_name      TEXT,
      monthly_amount  REAL NOT NULL CHECK (monthly_amount >= 0),
      discount_amount REAL NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
      is_active       INTEGER NOT NULL DEFAULT 1,
      created_at      TEXT NOT NULL,
      updated_at      TEXT NOT NULL
    )
    ''',
    // One rule per class (NULL rows are not constrained by a plain unique
    // index, so the partial index below limits them to one).
    'CREATE UNIQUE INDEX idx_fee_structures_class '
        'ON fee_structures(class_name)',
    // At most one global default rule. A plain UNIQUE index would not work:
    // SQLite treats NULLs as distinct, so a unique index on class_name allows
    // any number of NULL (default) rows. Indexing the constant expression `1`
    // (only rows where class_name IS NULL are in the index) gives every
    // default row the same non-NULL key, so the constraint really fires.
    'CREATE UNIQUE INDEX idx_fee_structures_default '
        'ON fee_structures((1)) WHERE class_name IS NULL',
    // A student has at most one charge per month, which also makes fee
    // generation idempotent.
    'CREATE UNIQUE INDEX idx_fee_records_student_period '
        'ON fee_records(student_id, period_start)',
    'CREATE INDEX idx_fee_records_period ON fee_records(period_start)',
    // Fee record: breakdown and running balances.
    'ALTER TABLE fee_records ADD COLUMN discount REAL NOT NULL DEFAULT 0 '
        'CHECK (discount >= 0)',
    'ALTER TABLE fee_records ADD COLUMN fine REAL NOT NULL DEFAULT 0 '
        'CHECK (fine >= 0)',
    'ALTER TABLE fee_records ADD COLUMN net_payable REAL NOT NULL DEFAULT 0 '
        'CHECK (net_payable >= 0)',
    'ALTER TABLE fee_records ADD COLUMN paid_amount REAL NOT NULL DEFAULT 0 '
        'CHECK (paid_amount >= 0)',
    'ALTER TABLE fee_records ADD COLUMN remaining_amount REAL NOT NULL DEFAULT 0 '
        'CHECK (remaining_amount >= 0)',
    // Payments: attribution and controlled reversal. A reversed payment is
    // never deleted — it is flagged and its balance is restored in the same
    // transaction.
    'ALTER TABLE payments ADD COLUMN note TEXT',
    'ALTER TABLE payments ADD COLUMN created_by INTEGER REFERENCES users(id)',
    'ALTER TABLE payments ADD COLUMN created_by_name TEXT',
    'ALTER TABLE payments ADD COLUMN status TEXT NOT NULL DEFAULT \'active\' '
        'CHECK (status IN (\'active\', \'reversed\'))',
    'ALTER TABLE payments ADD COLUMN reversed_at TEXT',
    'ALTER TABLE payments ADD COLUMN reversed_by INTEGER REFERENCES users(id)',
    'ALTER TABLE payments ADD COLUMN reversed_by_name TEXT',
    'ALTER TABLE payments ADD COLUMN reverse_reason TEXT',
    // Receipt numbers are unique when provided (legacy rows may lack one).
    'CREATE UNIQUE INDEX idx_payments_receipt_number ON payments(receipt_number) '
        'WHERE receipt_number IS NOT NULL AND receipt_number <> \'\'',
    'CREATE INDEX idx_payments_status ON payments(status)',
  ],
);
