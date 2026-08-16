import 'package:flutter/material.dart';
import 'package:school_office_management/features/reports/domain/repositories/report_repository.dart';

import '../../dashboard/dashboard_screen.dart';
import '../../dashboard/domain/services/dashboard_service.dart';
import '../../employee/domain/services/employee_service.dart';
import '../../family/domain/services/family_service.dart';
import '../../fee/application/fee_service.dart';
import '../../import/application/import_service.dart';
import '../../expense/domain/services/expense_service.dart';
import '../../salary/domain/services/salary_service.dart';
import '../../settings/domain/services/settings_service.dart';
import '../../student/domain/services/student_service.dart';
import '../domain/services/auth_service.dart';
import 'login_screen.dart';
import 'setup_admin_screen.dart';

/// Root-level widget that decides which screen the application shows based on
/// the current session state:
///   logged in       → Dashboard
///   no account yet  → First-run setup
///   otherwise       → Login screen
///
/// Using this gate (instead of unprotected named routes) means an
/// unauthenticated user can never reach the dashboard.
class AuthGate extends StatelessWidget {
  const AuthGate({
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
    required this.reportRepository,
    required this.settingsService,
    this.onOpenBackup,
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
  final ReportRepository reportRepository;
  final SettingsService settingsService;
  final void Function()? onOpenBackup;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authService,
      builder: (context, _) {
        if (authService.isAuthenticated) {
          return DashboardScreen(
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
            onOpenBackup: onOpenBackup,
          );
        }
        if (authService.setupRequired) {
          return SetupAdminScreen(authService: authService);
        }
        return LoginScreen(authService: authService);
      },
    );
  }
}
