import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../shared/utils/formatters.dart';
import '../admission/presentation/admission_wizard_screen.dart';
import '../auth/domain/services/auth_service.dart';
import '../employee/domain/services/employee_service.dart';
import '../employee/presentation/employee_list_screen.dart';
import '../family/domain/services/family_service.dart';
import '../family/presentation/family_form_screen.dart';
import '../family/presentation/family_list_screen.dart';
import '../fee/application/fee_service.dart';
import '../fee/presentation/fee_screen.dart';
import '../import/application/import_service.dart';
import '../import/presentation/import_screen.dart';
import '../salary/domain/services/salary_service.dart';
import '../salary/presentation/salary_screen.dart';
import '../settings/domain/services/settings_service.dart';
import '../student/domain/services/student_service.dart';
import '../student/presentation/student_form_screen.dart';
import 'package:school_office_management/features/reports/domain/repositories/report_repository.dart';
import '../student/presentation/student_list_screen.dart';
import '../expense/domain/services/expense_service.dart';
import '../expense/presentation/expense_screen.dart';
import 'domain/entities/dashboard_summary.dart';
import 'domain/services/dashboard_service.dart';
import 'presentation/widgets/empty_state_panel.dart';
import 'presentation/widgets/quick_action_button.dart';
import 'presentation/widgets/recent_activity_panel.dart';
import 'presentation/widgets/stat_card.dart';

/// Module 2: the school dashboard. Every figure is computed from SQLite by
/// [DashboardService]; the UI only formats and displays the summary.
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
  @override
  void initState() {
    super.initState();
    widget.dashboardService.load();
  }

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

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: widget.settingsService,
          builder: (context, _) {
            final schoolName = widget.settingsService.profile.schoolName;
            return Text(
              schoolName.isEmpty ? AppConfig.appName : schoolName,
              key: const Key('dashboard_title'),
            );
          },
        ),
        actions: [
          IconButton(
            key: const Key('settings_button'),
            tooltip: 'School settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              key: const Key('logout_button'),
              onPressed: widget.authService.logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.dashboardService,
        builder: (context, _) {
          final service = widget.dashboardService;
          if (service.isLoading && service.summary == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (service.error != null && service.summary == null) {
            return _ErrorPanel(onRetry: service.load);
          }
          final summary = service.summary ?? DashboardSummary.empty;
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
      ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreeting(theme),
          const SizedBox(height: 20),
          if (summary.isEmpty) ...[
            const EmptyStatePanel(),
            const SizedBox(height: 24),
          ],
          _SectionHeader(title: 'Overview'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatCard(
                label: 'Active Students',
                value: '${summary.activeStudents}',
                icon: Icons.school_rounded,
                color: Colors.blue,
                onTap: onOpenStudents,
              ),
              StatCard(
                label: 'Families',
                value: '${summary.families}',
                icon: Icons.family_restroom,
                color: Colors.teal,
                onTap: onOpenFamilies,
              ),
              StatCard(
                label: 'Active Staff',
                value: '${summary.activeEmployees}',
                icon: Icons.badge_rounded,
                color: Colors.purple,
                onTap: onOpenEmployees,
              ),
              StatCard(
                label: "Today's Collection",
                value: Formatters.money(summary.todayCollection),
                icon: Icons.today_rounded,
                color: Colors.green,
              ),
              StatCard(
                label: 'This Month Collection',
                value: Formatters.money(summary.monthCollection),
                icon: Icons.calendar_month_rounded,
                color: Colors.green.shade700,
              ),
              StatCard(
                label: 'Outstanding Fees',
                value: Formatters.money(summary.outstandingFees),
                icon: Icons.currency_rupee,
                color: Colors.orange,
              ),
              StatCard(
                label: 'This Month Salary',
                value: Formatters.money(summary.monthSalary),
                icon: Icons.payments_rounded,
                color: Colors.indigo,
                onTap: onOpenSalary,
              ),
              StatCard(
                label: 'Pending Salaries',
                value: Formatters.money(summary.monthPendingSalary),
                icon: Icons.schedule_rounded,
                color: Colors.deepOrange,
                onTap: onOpenSalary,
              ),
              StatCard(
                label: 'This Month Expenses',
                value: Formatters.money(summary.monthExpenses),
                icon: Icons.receipt_long_rounded,
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _SectionHeader(title: 'Quick Actions'),
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
          const _SectionHeader(title: 'Recent Activity'),
          const SizedBox(height: 12),
          _buildRecentActivity(theme),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildGreeting(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $greeting',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$roleLabel — ${Formatters.dateWithWeekday(summary.asOf)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(ThemeData theme) {
    final panels = [
      RecentActivityPanel(
        title: 'Payments',
        icon: Icons.payments_rounded,
        color: Colors.green,
        items: summary.recentPayments,
      ),
      RecentActivityPanel(
        title: 'Admissions',
        icon: Icons.how_to_reg_rounded,
        color: Colors.blue,
        items: summary.recentAdmissions,
      ),
      RecentActivityPanel(
        title: 'Expenses',
        icon: Icons.receipt_long_rounded,
        color: Colors.red,
        items: summary.recentExpenses,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1100) {
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
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
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
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'The dashboard could not be loaded.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
