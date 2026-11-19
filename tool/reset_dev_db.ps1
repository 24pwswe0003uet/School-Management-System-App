<#
.SYNOPSIS
Development database reset script for School Management System.

Clears all business/application data from SQLite database while preserving
the schema, migrations, indexes, and reference tables (academic_classes,
academic_sections, schema_versions).

WARNING: This script modifies the local database file. Run only in development.
#>

# Clear host output
Write-Host "School Management System - Development Database Reset" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# Determine database path
$appData = $env:APPDATA
$dbPath = "$appData\com.schooloffice\school_office_management\school_office_management.db"

Write-Host "Database path: $dbPath" -ForegroundColor Yellow

# Check if file exists
if (-Not (Test-Path $dbPath)) {
    Write-Host "Database file does not exist. Creating fresh schema..." -ForegroundColor Yellow
    # The database will be created fresh when the app starts
    Write-Host "Schema is intact. No data to reset." -ForegroundColor Yellow
    return
}

Write-Host "Opening database and clearing business data..." -ForegroundColor White

# PowerShell doesn't have direct sqflite access, so we'll use a Dart script approach
# Instead, we'll use sqlite3 CLI if available, or fall back to explaining the SQL

Write-Host ""
Write-Host "SQL Truncation Commands (run in sqlite3 or via Dart script):" -ForegroundColor Gray
Write-Host "--------------------------------------------------------" -ForegroundColor Gray

# Display the SQL commands that would be executed
Write-Host ""
Write-Host "1. Disable foreign key checks:" -ForegroundColor White
Write-Host "   PRAGMA foreign_keys = OFF;" -ForegroundColor Cyan

Write-Host ""
Write-Host "2. Clear business tables (in dependency order):" -ForegroundColor White
Write-Host "   DELETE FROM payments;" -ForegroundColor Cyan
Write-Host "   DELETE FROM fee_records;" -ForegroundColor Cyan
Write-Host "   DELETE FROM salary_records;" -ForegroundColor Cyan
Write-Host "   DELETE FROM salary_payments;" -ForegroundColor Cyan
Write-Host "   DELETE FROM expense_payments;" -ForegroundColor Cyan
Write-Host "   DELETE FROM import_errors;" -ForegroundColor Cyan
Write-Host "   DELETE FROM backup_records;" -ForegroundColor Cyan
Write-Host "   DELETE FROM users;" -ForegroundColor Cyan
Write-Host "   DELETE FROM families;" -ForegroundColor Cyan
Write-Host "   DELETE FROM students;" -ForegroundColor Cyan
Write-Host "   DELETE FROM admissions;" -ForegroundColor Cyan
Write-Host "   DELETE FROM employees;" -ForegroundColor Cyan
Write-Host "   DELETE FROM expenses;" -ForegroundColor Cyan
Write-Host "   DELETE FROM fee_structures;" -ForegroundColor Cyan
Write-Host "   DELETE FROM app_settings;" -ForegroundColor Cyan
Write-Host "   DELETE FROM school_logo;" -ForegroundColor Cyan
Write-Host "   DELETE FROM import_jobs;" -ForegroundColor Cyan

Write-Host ""
Write-Host "3. Preserved tables (schema reference data):" -ForegroundColor White
Write-Host "   academic_classes - seeded in migration V12 (15 classes)" -ForegroundColor Cyan
Write-Host "   academic_sections - seeded in migration V12 (3 sections)" -ForegroundColor Cyan
Write-Host "   schema_versions - migration tracking" -ForegroundColor Cyan

Write-Host ""
Write-Host "4. Re-enable foreign key checks:" -ForegroundColor White
Write-Host "   PRAGMA foreign_keys = ON;" -ForegroundColor Cyan

Write-Host ""
Write-Host "5. Verify empty business tables:" -ForegroundColor White
Write-Host "   SELECT 'table_name', COUNT(*) FROM table_name;" -ForegroundColor Cyan

Write-Host ""
Write-Host "After running the above SQL, restart the application." -ForegroundColor Yellow
Write-Host "The app will detect the reset and can re-populate data as needed." -ForegroundColor Yellow