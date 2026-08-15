import 'migration.dart';

/// Schema version 4: extends the Module 2 `students` table with the fields the
/// Student Management module needs — admission date, an optional contact
/// reference, notes — plus a dedicated history table for class/section/status
/// changes and indexes for the commonly searched columns.
///
/// All statements are additive so existing databases upgrade in place. The
/// admission number uniqueness is enforced only when the school actually uses
/// one (non-empty values), so a plain optional column is never a blocker.
const Migration migrationV4 = Migration(
  version: 4,
  statements: [
    'ALTER TABLE students ADD COLUMN admission_date TEXT',
    'ALTER TABLE students ADD COLUMN contact_reference TEXT',
    'ALTER TABLE students ADD COLUMN notes TEXT',
    '''
    CREATE TABLE student_history (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
      class      TEXT,
      section    TEXT,
      status     TEXT,
      changed_at TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
    ''',
    // Admission number is unique when used, but '' is treated as "not used".
    // NOCASE so "ADM-100" and "adm-100" are the same number.
    "CREATE UNIQUE INDEX idx_students_admission_number_unique "
        "ON students(admission_number COLLATE NOCASE) "
        "WHERE admission_number IS NOT NULL AND admission_number <> ''",
    'CREATE INDEX idx_students_admission_number ON students(admission_number)',
    'CREATE INDEX idx_students_class ON students(class)',
    'CREATE INDEX idx_students_section ON students(section)',
    'CREATE INDEX idx_student_history_student ON student_history(student_id)',
  ],
);
