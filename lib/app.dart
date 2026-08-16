import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'features/auth/domain/services/auth_service.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/backup/domain/services/backup_service.dart';
import 'features/backup/domain/services/data_export_service.dart';
import 'features/backup/presentation/backup_screen.dart';
import 'features/dashboard/domain/services/dashboard_service.dart';
import 'features/employee/domain/services/employee_service.dart';
import 'features/expense/domain/services/expense_service.dart';
import 'features/family/domain/services/family_service.dart';
import 'features/fee/application/fee_service.dart';
import 'features/import/application/import_service.dart';
import 'features/reports/domain/entities/report_definition.dart';
import 'features/reports/domain/entities/report_filter.dart';
import 'features/reports/domain/services/report_export_service.dart';
import 'features/reports/domain/repositories/report_repository.dart';
import 'features/reports/presentation/admission_reports_screen.dart';
import 'features/reports/presentation/employee_reports_screen.dart';
import 'features/reports/presentation/expense_reports_screen.dart';
import 'features/reports/presentation/fee_reports_screen.dart';
import 'features/reports/presentation/financial_reports_screen.dart';
import 'features/reports/presentation/report_view_screen.dart';
import 'features/reports/presentation/reports_hub_screen.dart';
import 'features/reports/presentation/salary_reports_screen.dart';
import 'features/reports/presentation/student_reports_screen.dart';
import 'features/salary/domain/services/salary_service.dart';
import 'features/settings/domain/services/settings_service.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/student/domain/services/student_service.dart';
import 'shared/theme/app_theme.dart';

class SchoolOfficeApp extends StatelessWidget {
  const SchoolOfficeApp({
    super.key,
    required this.authService,
    required this.dashboardService,
    required this.familyService,
    required this.studentService,
    required this.feeService,
    required this.importService,
    required this.employeeService,
    required this.salaryService,
    required this.expenseService,
    required this.reportExportService,
    required this.reportRepository,
    required this.settingsService,
    required this.backupService,
    required this.dataExportService,
  });

  final AuthService authService;
  final DashboardService dashboardService;
  final FamilyService familyService;
  final StudentService studentService;
  final FeeService feeService;
  final ImportService importService;
  final EmployeeService employeeService;
  final SalaryService salaryService;
  final ExpenseService expenseService;
  final ReportExportService reportExportService;
  final ReportRepository reportRepository;
  final SettingsService settingsService;
  final BackupService backupService;
  final DataExportService dataExportService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/reports/hub':
            return MaterialPageRoute(
              builder: (_) =>
                  ReportsHubScreen(reportRepository: reportRepository),
            );
          case '/reports/student':
            return MaterialPageRoute(
              builder: (_) => StudentReportsScreen(
                reportRepository: reportRepository,
              ),
            );
          case '/reports/admission':
            return MaterialPageRoute(
              builder: (_) => AdmissionReportsScreen(
                reportRepository: reportRepository,
              ),
            );
          case '/reports/fee':
            return MaterialPageRoute(
              builder: (_) =>
                  FeeReportsScreen(reportRepository: reportRepository),
            );
          case '/reports/employee':
            return MaterialPageRoute(
              builder: (_) => EmployeeReportsScreen(
                reportRepository: reportRepository,
              ),
            );
          case '/reports/salary':
            return MaterialPageRoute(
              builder: (_) => SalaryReportsScreen(
                reportRepository: reportRepository,
              ),
            );
          case '/reports/expense':
            return MaterialPageRoute(
              builder: (_) => ExpenseReportsScreen(
                reportRepository: reportRepository,
              ),
            );
          case '/reports/financial':
            return MaterialPageRoute(
              builder: (_) => FinancialReportsScreen(
                reportRepository: reportRepository,
              ),
            );
          case '/reports/view':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => ReportViewScreen(
                reportRepository: args['repository'] as ReportRepository,
                definition: args['definition'] as ReportDefinition,
                filtersApplied: args['filters'] as List<ReportFilter>,
                exportService: reportExportService,
                settingsService: settingsService,
              ),
            );
           case '/settings':
            return MaterialPageRoute(
              builder: (_) => SettingsScreen(
                settingsService: settingsService,
                feeService: feeService,
              ),
            );
          case '/backup':
            return MaterialPageRoute(
              builder: (_) => BackupScreen(
                service: backupService,
                dataExportService: dataExportService,
              ),
            );
          default:
            return null;
        }
      },
      home: AuthGate(
        authService: authService,
        dashboardService: dashboardService,
        familyService: familyService,
        studentService: studentService,
        feeService: feeService,
        importService: importService,
        employeeService: employeeService,
        salaryService: salaryService,
        expenseService: expenseService,
        reportRepository: reportRepository,
        settingsService: settingsService,
      ),
    );
  }
}
