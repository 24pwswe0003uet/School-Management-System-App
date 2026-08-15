import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'features/auth/domain/services/auth_service.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/dashboard/domain/services/dashboard_service.dart';
import 'features/employee/domain/services/employee_service.dart';
import 'features/family/domain/services/family_service.dart';
import 'features/fee/application/fee_service.dart';
import 'features/import/application/import_service.dart';
import 'features/salary/domain/services/salary_service.dart';
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
  });

  final AuthService authService;
  final DashboardService dashboardService;
  final FamilyService familyService;
  final StudentService studentService;
  final FeeService feeService;
  final ImportService importService;
  final EmployeeService employeeService;
  final SalaryService salaryService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AuthGate(
        authService: authService,
        dashboardService: dashboardService,
        familyService: familyService,
        studentService: studentService,
        feeService: feeService,
        importService: importService,
        employeeService: employeeService,
        salaryService: salaryService,
      ),
    );
  }
}
