import 'migration.dart';

/// Schema version 5: completes the Admission Management module's admission
/// record. The Module 2 `admissions` table already kept a separate history row
/// (id, admission_id, student_id, admission_date, class, section, created_at);
/// this migration adds the remaining admission-record fields: the admission
/// number snapshot, the admission fee (when applicable) and notes.
///
/// All statements are additive so existing databases upgrade in place.
const Migration migrationV5 = Migration(
  version: 5,
  statements: [
    'ALTER TABLE admissions ADD COLUMN admission_number TEXT',
    'ALTER TABLE admissions ADD COLUMN admission_fee REAL NOT NULL DEFAULT 0 '
        'CHECK (admission_fee >= 0)',
    'ALTER TABLE admissions ADD COLUMN notes TEXT',
    'CREATE INDEX idx_admissions_number ON admissions(admission_number)',
  ],
);
