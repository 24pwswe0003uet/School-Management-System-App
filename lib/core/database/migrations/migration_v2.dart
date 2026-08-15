import 'migration.dart';

/// Schema version 2: the domain tables the dashboard aggregates over.
///
/// These are minimal, spec-aligned placeholders so the dashboard can compute
/// real numbers from SQLite. Later modules (Student, Family, Fee, Employee,
/// Expense) extend these tables via additive migrations rather than replacing
/// them.
const Migration migrationV2 = Migration(
  version: 2,
  statements: [
    '''
    CREATE TABLE families (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      family_id       TEXT NOT NULL UNIQUE,
      guardian_name   TEXT NOT NULL,
      mother_name     TEXT,
      phone           TEXT,
      alternate_phone TEXT,
      address         TEXT,
      notes           TEXT,
      created_at      TEXT NOT NULL,
      updated_at      TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE students (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id       TEXT NOT NULL UNIQUE,
      family_id        INTEGER REFERENCES families(id) ON DELETE SET NULL,
      name             TEXT NOT NULL,
      gender           TEXT CHECK (gender IN ('male', 'female', 'other')),
      date_of_birth    TEXT,
      class            TEXT,
      section          TEXT,
      admission_number TEXT,
      status           TEXT NOT NULL DEFAULT 'active'
                       CHECK (status IN ('active', 'left', 'transferred')),
      created_at       TEXT NOT NULL,
      updated_at       TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE employees (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      employee_id TEXT NOT NULL UNIQUE,
      name        TEXT NOT NULL,
      designation TEXT,
      contact     TEXT,
      address     TEXT,
      status      TEXT NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active', 'inactive')),
      created_at  TEXT NOT NULL,
      updated_at  TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE fee_records (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      fee_record_id   TEXT NOT NULL UNIQUE,
      student_id      INTEGER NOT NULL REFERENCES students(id),
      period_start    TEXT NOT NULL,
      period_end      TEXT NOT NULL,
      expected_amount REAL NOT NULL CHECK (expected_amount >= 0),
      status          TEXT NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'partial', 'paid', 'cancelled')),
      created_at      TEXT NOT NULL,
      updated_at      TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE payments (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      payment_id    TEXT NOT NULL UNIQUE,
      student_id    INTEGER NOT NULL REFERENCES students(id),
      fee_record_id INTEGER REFERENCES fee_records(id) ON DELETE SET NULL,
      amount        REAL NOT NULL CHECK (amount >= 0),
      payment_date  TEXT NOT NULL,
      receipt_number TEXT,
      discount      REAL NOT NULL DEFAULT 0 CHECK (discount >= 0),
      fine          REAL NOT NULL DEFAULT 0 CHECK (fine >= 0),
      created_at    TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE salary_records (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      employee_id  INTEGER NOT NULL REFERENCES employees(id),
      period_start TEXT NOT NULL,
      period_end   TEXT NOT NULL,
      base_salary  REAL NOT NULL CHECK (base_salary >= 0),
      advance      REAL NOT NULL DEFAULT 0 CHECK (advance >= 0),
      deduction    REAL NOT NULL DEFAULT 0 CHECK (deduction >= 0),
      net_amount   REAL NOT NULL CHECK (net_amount >= 0),
      payment_date TEXT,
      status       TEXT NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('paid', 'pending')),
      created_at   TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE admissions (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      admission_id   TEXT NOT NULL UNIQUE,
      student_id     INTEGER NOT NULL REFERENCES students(id),
      admission_date TEXT NOT NULL,
      class          TEXT,
      section        TEXT,
      created_at     TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE expenses (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      expense_id  TEXT NOT NULL UNIQUE,
      date        TEXT NOT NULL,
      category    TEXT,
      amount      REAL NOT NULL CHECK (amount >= 0),
      description TEXT,
      notes       TEXT,
      created_at  TEXT NOT NULL
    )
    ''',
    // Indexes over the columns the dashboard filters and joins on.
    'CREATE INDEX idx_students_status ON students(status)',
    'CREATE INDEX idx_students_family ON students(family_id)',
    'CREATE INDEX idx_students_name ON students(name)',
    'CREATE INDEX idx_fee_records_status ON fee_records(status)',
    'CREATE INDEX idx_fee_records_student ON fee_records(student_id)',
    'CREATE INDEX idx_payments_student ON payments(student_id)',
    'CREATE INDEX idx_payments_date ON payments(payment_date)',
    'CREATE INDEX idx_payments_fee_record ON payments(fee_record_id)',
    'CREATE INDEX idx_employees_status ON employees(status)',
    'CREATE INDEX idx_salary_records_employee ON salary_records(employee_id)',
    'CREATE INDEX idx_salary_records_date ON salary_records(payment_date)',
    'CREATE INDEX idx_expenses_date ON expenses(date)',
    'CREATE INDEX idx_admissions_student ON admissions(student_id)',
    'CREATE INDEX idx_admissions_date ON admissions(admission_date)',
  ],
);
