import 'package:flutter/material.dart';

import '../domain/services/salary_service.dart';
import 'salary_form_screen.dart';
import 'salary_records_screen.dart';

/// Module 9 hub. Reached from the dashboard "Salaries" quick action and routes
/// to the salary records and monthly totals features.
class SalaryScreen extends StatelessWidget {
  const SalaryScreen({super.key, required this.salaryService});

  final SalaryService salaryService;

  Future<void> _push(BuildContext context, Widget screen) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Future<void> _record(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalaryFormScreen(salaryService: salaryService),
      ),
    );
    salaryService.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salary Management')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SalaryMenuTile(
            key: const Key('salary_menu_records'),
            icon: Icons.payments_rounded,
            color: Colors.indigo,
            title: 'Salary Records',
            subtitle: 'Search and review monthly salaries by employee, month '
                'or status.',
            onTap: () => _push(
              context,
              SalaryRecordsScreen(salaryService: salaryService),
            ),
          ),
          _SalaryMenuTile(
            key: const Key('salary_menu_record_salary'),
            icon: Icons.add_card_rounded,
            color: Colors.green,
            title: 'Record Salary',
            subtitle:
                'Create a monthly salary record for a staff member.',
            onTap: () => _record(context),
          ),
        ],
      ),
    );
  }
}

class _SalaryMenuTile extends StatelessWidget {
  const _SalaryMenuTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
