import 'package:flutter/material.dart';

import '../domain/services/expense_service.dart';
import 'expense_form_screen.dart';
import 'expense_list_screen.dart';
import 'expense_reports_screen.dart';

/// Module 10 hub. Reached from the dashboard or navigation, routes to every
/// expense feature.
class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({super.key, required this.expenseService});

  final ExpenseService expenseService;

  Future<void> _push(BuildContext context, Widget screen) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Management')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ExpenseMenuTile(
            key: const Key('expense_menu_list'),
            icon: Icons.receipt_long_rounded,
            color: Colors.red,
            title: 'Expense List',
            subtitle:
                'Search, filter and review expense records by date, category, '
                'amount or reference.',
            onTap: () => _push(
              context,
              ExpenseListScreen(expenseService: expenseService),
            ),
          ),
          _ExpenseMenuTile(
            key: const Key('expense_menu_add'),
            icon: Icons.add_card_rounded,
            color: Colors.green,
            title: 'Add Expense',
            subtitle: 'Record a new school expense.',
            onTap: () => _push(
              context,
              ExpenseFormScreen(expenseService: expenseService),
            ),
          ),
          _ExpenseMenuTile(
            key: const Key('expense_menu_reports'),
            icon: Icons.insert_chart_rounded,
            color: Colors.purple,
            title: 'Reports',
            subtitle:
                'Monthly totals, category breakdown, date-range reports, export.',
            onTap: () => _push(
              context,
              ExpenseReportsScreen(expenseService: expenseService),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseMenuTile extends StatelessWidget {
  const _ExpenseMenuTile({
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