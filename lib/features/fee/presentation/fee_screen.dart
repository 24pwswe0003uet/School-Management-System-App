import 'package:flutter/material.dart';

import '../application/fee_service.dart';
import 'collect_payment_screen.dart';
import 'fee_generate_screen.dart';
import 'fee_records_screen.dart';
import 'fee_reports_screen.dart';
import 'fee_structures_screen.dart';

/// Module 7 hub. Reached from the dashboard "Collect Fee" quick action and
/// routes to every fee feature.
class FeeScreen extends StatelessWidget {
  const FeeScreen({super.key, required this.feeService});

  final FeeService feeService;

  Future<void> _push(BuildContext context, Widget screen) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fee Management')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FeeMenuTile(
            key: const Key('fee_menu_collect'),
            icon: Icons.payments_rounded,
            color: Colors.green,
            title: 'Collect Payment',
            subtitle: 'Search a student and record a payment with a receipt.',
            onTap: () => _push(
              context,
              CollectPaymentScreen(feeService: feeService),
            ),
          ),
          _FeeMenuTile(
            key: const Key('fee_menu_records'),
            icon: Icons.receipt_long_rounded,
            color: Colors.indigo,
            title: 'Fee Records',
            subtitle:
                'Search and review monthly fee records by student, class, '
                'month or status.',
            onTap: () => _push(
              context,
              FeeRecordsScreen(feeService: feeService),
            ),
          ),
          _FeeMenuTile(
            key: const Key('fee_menu_generate'),
            icon: Icons.auto_awesome_rounded,
            color: Colors.teal,
            title: 'Generate Monthly Fee',
            subtitle: "Create the month's fee charges for all active students.",
            onTap: () => _push(
              context,
              FeeGenerateScreen(feeService: feeService),
            ),
          ),
          _FeeMenuTile(
            key: const Key('fee_menu_structures'),
            icon: Icons.rule_rounded,
            color: Colors.orange,
            title: 'Fee Structures',
            subtitle: 'Monthly fee rules per class and the default rule.',
            onTap: () => _push(
              context,
              FeeStructuresScreen(feeService: feeService),
            ),
          ),
          _FeeMenuTile(
            key: const Key('fee_menu_reports'),
            icon: Icons.insert_chart_rounded,
            color: Colors.purple,
            title: 'Reports',
            subtitle:
                'Collection, unpaid students, outstanding, family balances '
                'and student history.',
            onTap: () => _push(
              context,
              FeeReportsScreen(feeService: feeService),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeMenuTile extends StatelessWidget {
  const _FeeMenuTile({
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
