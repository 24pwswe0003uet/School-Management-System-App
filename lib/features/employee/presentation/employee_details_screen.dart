import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../../salary/domain/entities/salary_employee_pick.dart';
import '../../salary/domain/services/salary_service.dart';
import '../../salary/presentation/salary_form_screen.dart';
import '../domain/entities/employee_details.dart';
import '../domain/entities/employee_salary_record.dart';
import '../domain/services/employee_service.dart';
import 'employee_form_screen.dart';
import 'widgets/employee_status_chip.dart';

/// Employee profile: record details, salary history and summary, and actions
/// (record salary, edit, deactivate/reactivate, delete when no salary history
/// exists).
class EmployeeDetailsScreen extends StatefulWidget {
  const EmployeeDetailsScreen({
    super.key,
    required this.employeeService,
    required this.salaryService,
    required this.employeeId,
  });

  final EmployeeService employeeService;
  final SalaryService salaryService;
  final int employeeId;

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  EmployeeDetails? _details;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await widget.employeeService.getEmployeeDetails(
        widget.employeeId,
      );
      if (mounted) setState(() => _details = details);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recordSalary() async {
    final employee = _details!.employee;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalaryFormScreen(
          salaryService: widget.salaryService,
          employee: SalaryEmployeePick(
            id: employee.id,
            employeeCode: employee.employeeId,
            name: employee.name,
            designation: employee.designation,
            basicSalary: employee.basicSalary,
          ),
        ),
      ),
    );
    await _load();
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmployeeFormScreen(
          employeeService: widget.employeeService,
          salaryService: widget.salaryService,
          existing: _details!.employee,
        ),
      ),
    );
    if (updated != null) await _load();
  }

  Future<void> _toggleStatus() async {
    final employee = _details!.employee;
    if (employee.isArchived) {
      await widget.employeeService.reactivateEmployee(employee.id);
    } else {
      await widget.employeeService.deactivateEmployee(employee.id);
    }
    await _load();
  }

  Future<void> _delete() async {
    final employee = _details!.employee;
    if (_details!.salaryRecordCount > 0) {
      final deactivate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Employee cannot be deleted'),
          content: Text(
            '${employee.employeeId} has '
            '${_details!.salaryRecordCount} salary '
            'record${_details!.salaryRecordCount == 1 ? '' : 's'}. Staff with '
            'salary history are never deleted. You can deactivate them instead.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('employee_deactivate_from_delete'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (deactivate == true) {
        await widget.employeeService.deactivateEmployee(employee.id);
        await _load();
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete employee?'),
        content: Text(
          '${employee.employeeId} (${employee.name}) will be permanently '
          'deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('employee_delete_confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.employeeService.deleteEmployee(employee.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Details')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _details == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Employee could not be loaded.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final details = _details!;
    final employee = details.employee;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(24),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final infoCard = _buildInfoCard(theme, details);
            final salaryCard = _buildSalaryCard(theme, details);
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  infoCard,
                  const SizedBox(height: 16),
                  salaryCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: infoCard),
                const SizedBox(width: 16),
                SizedBox(width: 360, child: salaryCard),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Salary History (${details.salaryRecordCount})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (details.salaryHistory.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No salary records yet. Salary history will appear here once '
              'salaries are recorded.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < details.salaryHistory.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _salaryTile(theme, details.salaryHistory[i]),
                ],
              ],
            ),
          ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const Key('employee_record_salary'),
              onPressed: _recordSalary,
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Record Salary'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: const Key('employee_edit'),
              onPressed: _edit,
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: const Key('employee_status_toggle'),
              onPressed: _toggleStatus,
              icon: Icon(
                employee.isArchived ? Icons.unarchive : Icons.archive_outlined,
              ),
              label: Text(employee.isArchived ? 'Reactivate' : 'Deactivate'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: const Key('employee_delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Last updated ${Formatters.date(details.employee.updatedAt)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    ),
  ),
);
  }

  Widget _buildInfoCard(ThemeData theme, EmployeeDetails details) {
    final employee = details.employee;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  employee.employeeId,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                EmployeeStatusChip(status: employee.status),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow(theme, Icons.person, 'Name', employee.name),
            _infoRow(theme, Icons.work_outline, 'Designation',
                employee.designation ?? ''),
            _infoRow(
              theme,
              Icons.category_outlined,
              'Category',
              employee.category.label,
            ),
            if (employee.department != null && employee.department!.isNotEmpty)
              _infoRow(
                theme,
                Icons.apartment_outlined,
                'Department',
                employee.department!,
              ),
            if (employee.phone != null && employee.phone!.isNotEmpty)
              _infoRow(theme, Icons.phone, 'Phone', employee.phone!),
            if (employee.address != null && employee.address!.isNotEmpty)
              _infoRow(theme, Icons.home_outlined, 'Address', employee.address!),
            if (employee.cnic != null && employee.cnic!.isNotEmpty)
              _infoRow(theme, Icons.badge_outlined, 'CNIC', employee.cnic!),
            if (employee.joiningDate != null)
              _infoRow(
                theme,
                Icons.event_outlined,
                'Joining date',
                Formatters.date(employee.joiningDate!),
              ),
            if (employee.notes != null && employee.notes!.isNotEmpty)
              _infoRow(theme, Icons.notes, 'Notes', employee.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryCard(ThemeData theme, EmployeeDetails details) {
    final employee = details.employee;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Salary', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Text(
              Formatters.money(employee.basicSalary),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Current basic salary',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            _summaryLine(
              theme,
              'Paid so far',
              Formatters.money(details.totalPaid),
              Colors.green.shade700,
            ),
            const SizedBox(height: 8),
            _summaryLine(
              theme,
              'Pending',
              Formatters.money(details.totalPending),
              details.totalPending > 0
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryLine(
    ThemeData theme,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _salaryTile(ThemeData theme, EmployeeSalaryRecord record) {
    final period =
        '${Formatters.date(record.periodStart)} – '
        '${Formatters.date(record.periodEnd)}';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        child: Icon(
          Icons.payments_outlined,
          size: 20,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text(Formatters.monthYear(record.periodStart)),
      subtitle: Text(
        [
          period,
          if (record.paymentDate != null)
            'Paid ${Formatters.date(record.paymentDate!)}',
        ].join('\n'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formatters.money(record.netAmount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          _salaryStatusChip(theme, record.status),
        ],
      ),
    );
  }

  Widget _salaryStatusChip(ThemeData theme, SalaryStatus status) {
    final color = switch (status) {
      SalaryStatus.paid => Colors.green.shade700,
      SalaryStatus.pending => Colors.orange.shade800,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
