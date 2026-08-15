import 'package:flutter/material.dart';

import '../../domain/entities/salary_period.dart';

/// A stepper control for choosing a monthly salary period.
class SalaryPeriodPicker extends StatelessWidget {
  const SalaryPeriodPicker({
    super.key,
    required this.period,
    required this.onChanged,
  });

  final SalaryPeriod period;
  final ValueChanged<SalaryPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('salary_period_previous'),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous month',
          onPressed: () => onChanged(SalaryPeriod.previous(period)),
        ),
        Text(
          period.label,
          key: const Key('salary_period_label'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          key: const Key('salary_period_next'),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next month',
          onPressed: () => onChanged(SalaryPeriod.next(period)),
        ),
      ],
    );
  }
}
