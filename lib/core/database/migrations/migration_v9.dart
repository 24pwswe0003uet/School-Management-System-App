import 'migration.dart';

/// Schema version 9: extends the Module 2 `employees` table with the fields the
/// Employee Management module needs — an open-text category, an optional CNIC,
/// salary and note fields, and search indexes. All statements are additive so
/// existing databases upgrade in place.
///
/// The category is deliberately NOT a CHECK-constrained enum: the spec wants
/// categories to be extendable over time (Teacher / Office Staff / Other Staff
/// today, more later) without a schema migration. Validation lives in Dart.
const Migration migrationV9 = Migration(
  version: 9,
  statements: [
    // Category is required at the app level; the database defaults to the
    // generic bucket so any row created before the module lands stays valid.
    "ALTER TABLE employees ADD COLUMN category TEXT NOT NULL DEFAULT 'other_staff'",
    'ALTER TABLE employees ADD COLUMN department TEXT',
    // CNIC is optional ("if the school chooses to store it").
    'ALTER TABLE employees ADD COLUMN cnic TEXT',
    'ALTER TABLE employees ADD COLUMN joining_date TEXT',
    // Current basic salary, as a reference. History lives in salary_records.
    'ALTER TABLE employees ADD COLUMN basic_salary REAL NOT NULL DEFAULT 0 '
        'CHECK (basic_salary >= 0)',
    'ALTER TABLE employees ADD COLUMN notes TEXT',
    'CREATE INDEX idx_employees_name ON employees(name)',
    'CREATE INDEX idx_employees_designation ON employees(designation)',
    'CREATE INDEX idx_employees_category ON employees(category)',
  ],
);
