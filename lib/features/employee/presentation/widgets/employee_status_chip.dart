import 'package:flutter/material.dart';

import '../../domain/entities/employee_status.dart';

/// A coloured chip showing an employee's employment status.
class EmployeeStatusChip extends StatelessWidget {
  const EmployeeStatusChip({super.key, required this.status});

  final EmployeeStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      EmployeeStatus.active => Colors.green.shade700,
      EmployeeStatus.inactive => theme.colorScheme.outline,
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
}
