import 'package:flutter/material.dart';

import '../../domain/entities/student.dart';
import '../../domain/entities/student_list_item.dart';

/// A search result row showing everything needed to pick the right student:
/// Student ID, name, class/section, family, and status.
class StudentCard extends StatelessWidget {
  const StudentCard({super.key, required this.item, required this.onTap});

  final StudentListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final student = item.student;
    final details = [
      student.studentId,
      if (student.className != null && student.className!.isNotEmpty)
        student.className!,
      if (student.section != null && student.section!.isNotEmpty)
        student.section!,
    ].join(' · ');

    final family = [
      item.familyId,
      if (item.guardianName != null && item.guardianName!.isNotEmpty)
        item.guardianName!,
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(
            Icons.school_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(student.name),
        subtitle: Text(
          '$details\nFamily: $family',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: _statusChip(theme, student.status),
      ),
    );
  }

  static Widget _statusChip(ThemeData theme, StudentStatus status) {
    final color = switch (status) {
      StudentStatus.active => Colors.green.shade700,
      StudentStatus.left => theme.colorScheme.error,
      StudentStatus.transferred => Colors.blue.shade700,
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
