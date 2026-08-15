import 'package:flutter/material.dart';

import '../../domain/entities/employee.dart';
import 'employee_status_chip.dart';

/// A search result row showing everything needed to pick the right employee:
/// employee ID, name, category, designation/phone and status.
class EmployeeCard extends StatelessWidget {
  const EmployeeCard({super.key, required this.employee, required this.onTap});

  final Employee employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      employee.designation ?? '',
      if (employee.phone != null && employee.phone!.isNotEmpty) employee.phone!,
    ].where((part) => part.isNotEmpty).join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(
            Icons.badge_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(employee.name),
        subtitle: Text(
          '${employee.employeeId} · ${employee.category.label}'
          '${subtitle.isEmpty ? '' : '\n$subtitle'}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: EmployeeStatusChip(status: employee.status),
      ),
    );
  }
}
