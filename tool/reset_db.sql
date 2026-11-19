-- ============================================================
-- Development Database Reset Script
-- ============================================================
-- Clears all business/application data from SQLite database while
-- preserving the schema, migrations, indexes, and reference tables.
-- 
-- Prerequisites:
--   - Close the School Management System application
--   - Run these SQL commands using sqlite3 CLI or a SQLite manager
--   - Database file: %APPDATA%\com.schooloffice\school_office_management\school_office_management.db
--
-- After running: Restart the application. The app will detect the
-- cleared state and behave accordingly.
-- ============================================================

-- Step 1: Disable foreign key checks (required for ordered truncation)
PRAGMA foreign_keys = OFF;

-- ============================================================
-- Clear business/application tables (in FK-dependent order)
-- ============================================================

-- Clear fee/payment related tables (children)
DELETE FROM payments;
DELETE FROM fee_records;
DELETE FROM salary_payments;
DELETE FROM expense_payments;
DELETE FROM import_errors;
DELETE FROM backup_records;

-- Clear main business tables
DELETE FROM users;
DELETE FROM families;
DELETE FROM students;
DELETE FROM admissions;
DELETE FROM employees;
DELETE FROM expenses;

-- Clear fee structures (this will be re-classified by migration V13 on next start)
DELETE FROM fee_structures;

-- Clear application settings
DELETE FROM app_settings;

-- Clear school logo data
DELETE FROM school_logo;

-- Clear import jobs and errors
DELETE FROM import_jobs;

-- ============================================================
-- Preserve schema reference tables (do NOT delete)
-- ============================================================

-- academic_classes: seeded in migration V12 (15 classes: Play Group through 12)
-- These are the canonical class names used throughout the app
-- DELETE FROM academic_classes;  -- COMMENTED OUT: PRESERVE

-- academic_sections: seeded in migration V12 (3 sections: A, B, C)
-- DELETE FROM academic_sections;  -- COMMENTED OUT: PRESERVE

-- schema_versions: tracks applied migrations
-- DELETE FROM schema_versions;    -- COMMENTED OUT: PRESERVE

-- ============================================================
-- Re-enable foreign key checks
-- ============================================================

PRAGMA foreign_keys = ON;

-- ============================================================
-- Verification: Check row counts
-- ============================================================

-- Business tables should all be 0
SELECT 'business_table', COUNT(*) FROM users
UNION ALL SELECT 'business_table', COUNT(*) FROM families
UNION ALL SELECT 'business_table', COUNT(*) FROM students
UNION ALL SELECT 'business_table', COUNT(*) FROM admissions
UNION ALL SELECT 'business_table', COUNT(*) FROM employees
UNION ALL SELECT 'business_table', COUNT(*) FROM salary_records
UNION ALL SELECT 'business_table', COUNT(*) FROM fee_structures
UNION ALL SELECT 'business_table', COUNT(*) FROM app_settings
UNION ALL SELECT 'business_table', COUNT(*) FROM school_logo;

-- Reference tables should have data
SELECT 'reference_table', COUNT(*) FROM academic_classes
UNION ALL SELECT 'reference_table', COUNT(*) FROM academic_sections
UNION ALL SELECT 'reference_table', COUNT(*) FROM schema_versions;

-- ============================================================
-- Reset Complete
-- ============================================================

-- Re-enable FK checks for the application
PRAGMA foreign_keys = ON;

-- Note: On next application start, migration V13 will re-classify
-- fee_structures rules based on name keywords (admission vs monthly).
-- Migration V14 will ensure composite (class_name, fee_type) uniqueness.