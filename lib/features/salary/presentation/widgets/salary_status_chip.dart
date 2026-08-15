import 'package:flutter/material.dart';

import '../../domain/entities/salary_status.dart';

/// A small colored chip showing a salary record's payment status.
class SalaryStatusChip extends StatelessWidget {
  const SalaryStatusChip({super.key, required this.status});

  final SalaryStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SalaryStatus.paid => ('Paid', Colors.green),
      SalaryStatus.pending => ('Pending', Colors.orange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
