import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../shared/theme/app_breakpoints.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/formatters.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_page_header.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/app_stat_card.dart';
import '../admission/presentation/admission_wizard_screen.dart';
import '../auth/domain/services/auth_service.dart';
import '../backup/presentation/backup_screen.dart';
import '../employee/domain/services/employee_service.dart';
import '../employee/presentation/employee_list_screen.dart';
import '../expense/domain/services/expense_service.dart';
import '../expense/presentation/expense_screen.dart';
import '../family/domain/services/family_service.dart';
import '../family/presentation/family_form_screen.dart';
import '../family/presentation/family_list_screen.dart';
import '../fee/application/fee_service.dart';
import '../fee/presentation/fee_screen.dart';
import '../import/application/import_service.dart';
import '../import/presentation/import_screen.dart';
import '../reports/domain/repositories/report_repository.dart';
import '../reports/presentation/reports_hub_screen.dart';
import '../salary/domain/services/salary_service.dart';
import '../salary/presentation/salary_screen.dart';
import '../settings/domain/services/settings_service.dart';
import '../settings/presentation/settings_screen.dart';
import '../student/domain/services/student_service.dart';
import '../student/presentation/student_form_screen.dart';
import '../student/presentation/student_list_screen.dart';
import 'domain/entities/dashboard_summary.dart';
import 'domain/services/dashboard_service.dart';
import 'presentation/widgets/empty_state_panel.dart';
import 'presentation/widgets/quick_action_button.dart';
import 'presentation/widgets/recent_activity_panel.dart';

/// Modern Dashboard Screen wrapped seamlessly in persistent AppShell navigation.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
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
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.dashboardService.load();
  }

  static const List<AppNavDestination> _navDestinations = [
    AppNavDestination(label: 'Dashboard', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard),
    AppNavDestination(label: 'Students', icon: Icons.school_outlined, selectedIcon: Icons.school),
    AppNavDestination(label: 'Families', icon: Icons.family_restroom_outlined, selectedIcon: Icons.family_restroom),
    AppNavDestination(label: 'New Admission', icon: Icons.how_to_reg_outlined, selectedIcon: Icons.how_to_reg),
    AppNavDestination(label: 'Fees', icon: Icons.payments_outlined, selectedIcon: Icons.payments),
    AppNavDestination(label: 'Staff', icon: Icons.badge_outlined, selectedIcon: Icons.badge),
    AppNavDestination(label: 'Salaries', icon: Icons.attach_money_outlined, selectedIcon: Icons.attach_money),
    AppNavDestination(label: 'Expenses', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long),
    AppNavDestination(label: 'Reports', icon: Icons.analytics_outlined, selectedIcon: Icons.analytics),
    AppNavDestination(label: 'Import / Export', icon: Icons.import_export_outlined, selectedIcon: Icons.import_export),
    AppNavDestination(label: 'Backup & Restore', icon: Icons.backup_outlined, selectedIcon: Icons.backup),
    AppNavDestination(label: 'Settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings),
  ];

  Future<void> _openFamilies() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyListScreen(
          familyService: widget.familyService,
          studentService: widget.studentService,
          settingsService: widget.settingsService,
        ),
      ),
    );
    widget.dashboardService.load();
  }

  Future<void> _addFamily() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyFormScreen(
          familyService: widget.familyService,
          studentService: widget.studentService,
          settingsService: widget.settingsService,
        ),
      ),
    );
    widget.dashboardService.load();
  }

  Future<void> _openStudents() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentListScreen(
          studentService: widget.studentService,
          familyService: widget.familyService,
          settingsService: widget.settingsService,
        ),
      ),
    );
    widget.dashboardService.load();
  }

  Future<void> _addStudent() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentFormScreen(
          studentService: widget.studentService,
          familyService: widget.familyService,
          settingsService: widget.settingsService,
        ),
      ),
    );
    widget.dashboardService.load();
  }

  Future<void> _openNewAdmission() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdmissionWizardScreen(
          studentService: widget.studentService,
          familyService: widget.familyService,
          settingsService: widget.settingsService,
        ),
      ),
    );
    widget.dashboardService.load();
  }

  Future<void> _openImport() async {
    widget.importService.reset();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImportScreen(
          service: widget.importService,
          onFinished: widget.dashboardService.load,
        ),
      ),
    );
    widget.dashboardService.load();
  }

  Future<void> _openFee() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FeeScreen(
          feeService: widget.feeService,
          settingsService: widget.settingsService,
        ),
      ),
    );
    widget.dashboardService.load();
  }

  Future<void> _openEmployees() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmployeeListScreen(
          employeeService: widget.employeeService,
          salaryService: widget.salaryService,
        ),
      ),
    );
    widget.dashboardService.load();
  }

  Future<void> _openSalary() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalaryScreen(salaryService: widget.salaryService),
      ),
    );
    widget.dashboardService.load();
  }

  Future<void> _openExpense() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExpenseScreen(expenseService: widget.expenseService),
      ),
    );
    widget.dashboardService.load();
  }

  Future<void> _openReports() async {
    Navigator.pushNamed(context, '/reports/hub');
    widget.dashboardService.load();
  }

  Future<void> _exportStudents() async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await widget.importService.exportStudents();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Student export saved.'
              : widget.importService.errorMessage ??
                    'Export cancelled — no file was saved.',
        ),
      ),
    );
  }

  void _onNavSelected(int index) {
    setState(() => _currentNavIndex = index);
  }

  Widget _buildBodyForIndex(int index) {
    switch (index) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return StudentListScreen(
          studentService: widget.studentService,
          familyService: widget.familyService,
          settingsService: widget.settingsService,
        );
      case 2:
        return FamilyListScreen(
          familyService: widget.familyService,
          studentService: widget.studentService,
          settingsService: widget.settingsService,
        );
      case 3:
        return AdmissionWizardScreen(
          studentService: widget.studentService,
          familyService: widget.familyService,
          settingsService: widget.settingsService,
        );
      case 4:
        return FeeScreen(
          feeService: widget.feeService,
          settingsService: widget.settingsService,
        );
      case 5:
        return EmployeeListScreen(
          employeeService: widget.employeeService,
          salaryService: widget.salaryService,
        );
      case 6:
        return SalaryScreen(salaryService: widget.salaryService);
      case 7:
        return ExpenseScreen(expenseService: widget.expenseService);
      case 8:
        return ReportsHubScreen(reportRepository: widget.reportRepository);
      case 9:
        return ImportScreen(
          service: widget.importService,
          onFinished: widget.dashboardService.load,
        );
      case 10:
        if (widget.onOpenBackup != null) {
          widget.onOpenBackup!();
          return const SizedBox.shrink();
        }
        return const Center(child: Text('Backup opened'));
      case 11:
        return SettingsScreen(
          settingsService: widget.settingsService,
          feeService: widget.feeService,
        );
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return ListenableBuilder(
      listenable: widget.dashboardService,
      builder: (context, _) {
        final service = widget.dashboardService;
        if (service.isLoading && service.summary == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (service.error != null && service.summary == null) {
          return Center(
            child: AppErrorState(
              title: 'Dashboard could not be loaded',
              message: service.error ?? 'Please check connection and retry.',
              onRetry: service.load,
            ),
          );
        }
        final summary = service.summary ?? DashboardSummary.empty;
        final user = widget.authService.currentUser;

        return _DashboardBody(
          greeting: user?.displayName ?? '',
          roleLabel: user?.role.label ?? '',
          summary: summary,
          onOpenFamilies: _openFamilies,
          onAddFamily: _addFamily,
          onOpenStudents: _openStudents,
          onAddStudent: _addStudent,
          onNewAdmission: _openNewAdmission,
          onImportExcel: _openImport,
          onExportExcel: _exportStudents,
          onCollectFee: _openFee,
          onOpenEmployees: _openEmployees,
          onOpenSalary: _openSalary,
          onOpenExpense: _openExpense,
          onOpenReports: _openReports,
          onOpenBackup: widget.onOpenBackup ??
              () => Navigator.pushNamed(context, '/backup'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;

    return ListenableBuilder(
      listenable: widget.settingsService,
      builder: (context, _) {
        final schoolName = widget.settingsService.profile.schoolName;

        return AppShell(
          selectedIndex: _currentNavIndex,
          onDestinationSelected: _onNavSelected,
          destinations: _navDestinations,
          schoolName: schoolName.isEmpty ? AppConfig.appName : schoolName,
          userName: user?.displayName ?? user?.username ?? 'Admin',
          userRole: user?.role.label ?? 'Administrator',
          onLogout: widget.authService.logout,
          body: _buildBodyForIndex(_currentNavIndex),
        );
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.greeting,
    required this.roleLabel,
    required this.summary,
    required this.onOpenFamilies,
    required this.onAddFamily,
    required this.onOpenStudents,
    required this.onAddStudent,
    required this.onNewAdmission,
    required this.onImportExcel,
    required this.onExportExcel,
    required this.onCollectFee,
    required this.onOpenEmployees,
    required this.onOpenSalary,
    required this.onOpenExpense,
    required this.onOpenReports,
    required this.onOpenBackup,
  });

  final String greeting;
  final String roleLabel;
  final DashboardSummary summary;
  final VoidCallback onOpenFamilies;
  final VoidCallback onAddFamily;
  final VoidCallback onOpenStudents;
  final VoidCallback onAddStudent;
  final VoidCallback onNewAdmission;
  final VoidCallback onImportExcel;
  final VoidCallback onExportExcel;
  final VoidCallback onCollectFee;
  final VoidCallback onOpenEmployees;
  final VoidCallback onOpenSalary;
  final VoidCallback onOpenExpense;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenBackup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = AppBreakpoints.isDesktop(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPageHeader(
            title: 'Welcome, $greeting',
            subtitle: '$roleLabel — ${Formatters.dateWithWeekday(summary.asOf)}',
            actions: [
              FilledButton.icon(
                key: const Key('quick_collect_fee_header'),
                onPressed: onCollectFee,
                icon: const Icon(Icons.payments_rounded, size: 18),
                label: const Text('Collect Fee'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const Key('quick_new_admission_header'),
                onPressed: onNewAdmission,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('New Admission'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (summary.isEmpty) ...[
            const EmptyStatePanel(),
            const SizedBox(height: 24),
          ],
          const _SectionHeader(title: 'Overview & Key Metrics'),
          const SizedBox(height: 12),
          // Responsive Stat Cards Grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: isDesktop ? 220 : 160,
                child: AppStatCard(
                  title: 'Active Students',
                  value: '${summary.activeStudents}',
                  icon: Icons.school_rounded,
                  color: AppTheme.primaryNavy,
                  onTap: onOpenStudents,
                ),
              ),
              SizedBox(
                width: isDesktop ? 220 : 160,
                child: AppStatCard(
                  title: 'Families',
                  value: '${summary.families}',
                  icon: Icons.family_restroom,
                  color: Colors.teal,
                  onTap: onOpenFamilies,
                ),
              ),
              SizedBox(
                width: isDesktop ? 220 : 160,
                child: AppStatCard(
                  title: 'Active Staff',
                  value: '${summary.activeEmployees}',
                  icon: Icons.badge_rounded,
                  color: Colors.purple,
                  onTap: onOpenEmployees,
                ),
              ),
              SizedBox(
                width: isDesktop ? 220 : 160,
                child: AppStatCard(
                  title: "Today's Collection",
                  value: Formatters.money(summary.todayCollection),
                  icon: Icons.today_rounded,
                  color: AppTheme.successGreen,
                ),
              ),
              SizedBox(
                width: isDesktop ? 220 : 160,
                child: AppStatCard(
                  title: 'This Month Fee',
                  value: Formatters.money(summary.monthCollection),
                  icon: Icons.calendar_month_rounded,
                  color: AppTheme.successGreen,
                ),
              ),
              SizedBox(
                width: isDesktop ? 220 : 160,
                child: AppStatCard(
                  title: 'Outstanding Fees',
                  value: Formatters.money(summary.outstandingFees),
                  icon: Icons.priority_high_rounded,
                  color: AppTheme.dangerRed,
                ),
              ),
              SizedBox(
                width: isDesktop ? 220 : 160,
                child: AppStatCard(
                  title: 'Month Salaries',
                  value: Formatters.money(summary.monthSalary),
                  icon: Icons.payments_rounded,
                  color: Colors.indigo,
                  onTap: onOpenSalary,
                ),
              ),
              SizedBox(
                width: isDesktop ? 220 : 160,
                child: AppStatCard(
                  title: 'Pending Salaries',
                  value: Formatters.money(summary.monthPendingSalary),
                  icon: Icons.schedule_rounded,
                  color: AppTheme.warningAmber,
                  onTap: onOpenSalary,
                ),
              ),
              SizedBox(
                width: isDesktop ? 220 : 160,
                child: AppStatCard(
                  title: 'Month Expenses',
                  value: Formatters.money(summary.monthExpenses),
                  icon: Icons.receipt_long_rounded,
                  color: AppTheme.dangerRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _SectionHeader(title: 'Quick Operations'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              QuickActionButton(
                key: const Key('quick_add_family'),
                label: 'Add Family',
                icon: Icons.family_restroom,
                onTap: onAddFamily,
              ),
              QuickActionButton(
                key: const Key('quick_add_student'),
                label: 'Add Student',
                icon: Icons.person_add_rounded,
                onTap: onAddStudent,
              ),
              QuickActionButton(
                key: const Key('quick_new_admission'),
                label: 'New Admission',
                icon: Icons.how_to_reg_rounded,
                onTap: onNewAdmission,
              ),
              QuickActionButton(
                key: const Key('quick_collect_fee'),
                label: 'Collect Fee',
                icon: Icons.payments_rounded,
                onTap: onCollectFee,
              ),
              QuickActionButton(
                key: const Key('quick_add_expense'),
                label: 'Add Expense',
                icon: Icons.add_card_rounded,
                onTap: onOpenExpense,
              ),
              QuickActionButton(
                key: const Key('quick_add_staff'),
                label: 'Add Staff',
                icon: Icons.group_add_rounded,
                onTap: onOpenEmployees,
              ),
              QuickActionButton(
                key: const Key('quick_salaries'),
                label: 'Salaries',
                icon: Icons.payments_rounded,
                onTap: onOpenSalary,
              ),
              QuickActionButton(
                key: const Key('quick_reports'),
                label: 'Reports',
                icon: Icons.insert_chart_rounded,
                onTap: onOpenReports,
              ),
              QuickActionButton(
                key: const Key('quick_backup_restore'),
                label: 'Backup & Restore',
                icon: Icons.save_rounded,
                onTap: onOpenBackup,
              ),
              QuickActionButton(
                key: const Key('quick_search_student'),
                label: 'Search Student',
                icon: Icons.search_rounded,
                onTap: onOpenStudents,
              ),
              QuickActionButton(
                key: const Key('quick_import_excel'),
                label: 'Import from Excel',
                icon: Icons.upload_file_rounded,
                onTap: onImportExcel,
              ),
              QuickActionButton(
                key: const Key('quick_export_excel'),
                label: 'Export to Excel',
                icon: Icons.download_rounded,
                onTap: onExportExcel,
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _SectionHeader(title: 'Recent Activity Logs'),
          const SizedBox(height: 12),
          _buildRecentActivity(theme),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(ThemeData theme) {
    final panels = [
      RecentActivityPanel(
        title: 'Payments',
        icon: Icons.payments_rounded,
        color: AppTheme.successGreen,
        items: summary.recentPayments,
      ),
      RecentActivityPanel(
        title: 'Admissions',
        icon: Icons.how_to_reg_rounded,
        color: AppTheme.primaryNavy,
        items: summary.recentAdmissions,
      ),
      RecentActivityPanel(
        title: 'Expenses',
        icon: Icons.receipt_long_rounded,
        color: AppTheme.dangerRed,
        items: summary.recentExpenses,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1024) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < panels.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: panels[i]),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < panels.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              panels[i],
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
        letterSpacing: -0.2,
      ),
    );
  }
}
