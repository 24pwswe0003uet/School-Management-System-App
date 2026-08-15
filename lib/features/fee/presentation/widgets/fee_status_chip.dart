import 'package:flutter/material.dart';

import '../../domain/entities/fee_status.dart';

/// A small colored chip showing a fee record's payment status.
class FeeStatusChip extends StatelessWidget {
  const FeeStatusChip({super.key, required this.status});

  final FeeStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      FeeStatus.paid => ('Paid', Colors.green),
      FeeStatus.partial => ('Partial', Colors.orange),
      FeeStatus.unpaid => ('Unpaid', Colors.red),
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
