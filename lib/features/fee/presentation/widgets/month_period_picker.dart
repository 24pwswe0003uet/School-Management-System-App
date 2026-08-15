import 'package:flutter/material.dart';

import '../../domain/entities/fee_period.dart';

/// A stepper control for choosing a monthly period.
class MonthPeriodPicker extends StatelessWidget {
  const MonthPeriodPicker({
    super.key,
    required this.period,
    required this.onChanged,
  });

  final FeePeriod period;
  final ValueChanged<FeePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('period_previous'),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous month',
          onPressed: () => onChanged(FeePeriod.previous(period)),
        ),
        Text(
          period.label,
          key: const Key('period_label'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          key: const Key('period_next'),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next month',
          onPressed: () => onChanged(FeePeriod.next(period)),
        ),
      ],
    );
  }
}
