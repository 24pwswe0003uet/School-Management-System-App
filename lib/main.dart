import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/database/app_database.dart';
import 'core/database/database_factory.dart';
import 'core/services/backup_locator.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/services/auth_service.dart';
import 'features/backup/data/repositories/backup_repository_impl.dart';
import 'features/backup/domain/services/backup_service.dart';
import 'features/backup/domain/services/data_export_service.dart';
import 'features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'features/dashboard/domain/services/dashboard_service.dart';
import 'features/employee/data/repositories/employee_repository_impl.dart';
import 'features/employee/domain/services/employee_service.dart';
import 'features/expense/data/repositories/expense_repository_impl.dart';
import 'features/expense/domain/services/expense_service.dart';
import 'features/family/data/repositories/family_repository_impl.dart';
import 'features/family/domain/services/family_service.dart';
import 'features/fee/application/fee_service.dart';
import 'features/fee/data/repositories/fee_repository_impl.dart';
import 'features/import/application/import_service.dart';
import 'features/import/data/repositories/import_repository_impl.dart';
import 'features/import/domain/services/column_mapper.dart';
import 'features/import/domain/services/excel_reader.dart';
import 'features/import/domain/services/export_service.dart';
import 'features/reports/domain/services/report_export_service.dart';
import 'features/import/domain/services/import_planner.dart';
import 'features/reports/data/repositories/report_repository_impl.dart';
import 'features/salary/data/repositories/salary_repository_impl.dart';
import 'features/settings/data/logo_store/logo_store_factory.dart';
import 'features/settings/data/repositories/settings_repository_impl.dart';
import 'features/settings/domain/services/settings_service.dart';
import 'features/student/data/repositories/student_repository_impl.dart';
import 'features/salary/domain/services/salary_service.dart';
import 'features/student/domain/services/student_service.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Platform-appropriate SQLite backend (native FFI on Windows, WASM on web).
  initDatabaseFactory();

  await _startApp();
}

Future<void> _startApp() async {
  try {
    final database = await AppDatabase.open();
    final authService = AuthService(AuthRepositoryImpl(database));
    await authService.refreshSetupStatus();
    final dashboardService = DashboardService(
      DashboardRepositoryImpl(database.raw),
    );
    final familyService = FamilyService(FamilyRepositoryImpl(database.raw));
    final employeeService = EmployeeService(
      EmployeeRepositoryImpl(database.raw),
    );
    final salaryService = SalaryService(
      SalaryRepositoryImpl(database.raw),
    );
    final studentService = StudentService(StudentRepositoryImpl(database.raw));
    final feeService = FeeService(
      repository: FeeRepositoryImpl(database.raw),
      authService: authService,
    );
    final expenseRepository = ExpenseRepositoryImpl(database.raw);
    final expenseService = ExpenseService(expenseRepository);
    final reportRepository = ReportRepositoryImpl(database.raw);
    final reportExportService = ReportExportService();
    final settingsService = SettingsService(
      repository: SettingsRepositoryImpl(database.raw, createLogoStore()),
      authService: authService,
    );
    await settingsService.load();
    final importRepository = ImportRepositoryImpl(database.raw);
    final importService = ImportService(
      reader: ExcelReader(),
      mapper: ColumnMapper(),
      planner: ImportPlanner(),
      repository: importRepository,
      exportService: ExportService(importRepository),
    );

    // Module 13: Backup & Data Management.
    final backupLocator = createBackupLocator();
    final backupDirectory = await backupLocator.backupDirectory();
    final backupRepository = BackupRepositoryImpl(
      backupDirectory: backupDirectory,
    );
    final backupService = BackupService(
      database: database,
      repository: backupRepository,
      authService: authService,
    );
    final dataExportService = DataExportService(
      students: StudentRepositoryImpl(database.raw),
      families: FamilyRepositoryImpl(database.raw),
      employees: EmployeeRepositoryImpl(database.raw),
      salaries: SalaryRepositoryImpl(database.raw),
      expenses: expenseRepository,
      fees: FeeRepositoryImpl(database.raw),
    );

    runApp(
      SchoolOfficeApp(
        authService: authService,
        dashboardService: dashboardService,
        familyService: familyService,
        studentService: studentService,
        feeService: feeService,
        importService: importService,
        employeeService: employeeService,
        salaryService: salaryService,
        expenseService: expenseService,
        reportExportService: reportExportService,
        reportRepository: reportRepository,
        settingsService: settingsService,
        backupService: backupService,
        dataExportService: dataExportService,
      ),
    );
  } catch (_) {
    runApp(const StartupErrorScreen(onRetry: _startApp));
  }
}

/// Shown when the local database cannot be opened (e.g. corrupt or locked).
/// Keeps details generic — sensitive database internals are never shown.
class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 56,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'The application could not open its local data.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please close other running instances and try again. '
                      'If the problem continues, restore your latest backup.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => onRetry(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
