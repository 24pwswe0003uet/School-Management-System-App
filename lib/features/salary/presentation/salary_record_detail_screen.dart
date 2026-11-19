import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../domain/entities/salary_record_list_item.dart';
import '../domain/services/salary_service.dart';
import 'salary_form_screen.dart';
import 'widgets/salary_status_chip.dart';

/// Full view of one salary record: employee identity, components, net amount
/// and the controlled actions (mark paid, edit, delete-pending-only).
class SalaryRecordDetailScreen extends StatefulWidget {
  const SalaryRecordDetailScreen({
    super.key,
    required this.salaryService,
    required this.recordId,
  });

  final SalaryService salaryService;
  final int recordId;

  @override
  State<SalaryRecordDetailScreen> createState() =>
      _SalaryRecordDetailScreenState();
}

class _SalaryRecordDetailScreenState extends State<SalaryRecordDetailScreen> {
  SalaryRecordListItem? _item;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = await widget.salaryService.getSalaryRecordDetails(
        widget.recordId,
      );
      if (!mounted) return;
      setState(() {
        _item = item;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Salary record could not be loaded.';
        _loading = false;
      });
    }
  }

  Future<void> _markPaid() async {
    final item = _item;
    if (item == null || item.record.isPaid) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: item.record.paymentDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    try {
      await widget.salaryService.markPaid(id: item.record.id, paymentDate: picked);
      _showSnack('Salary marked as paid.');
      await _load();
    } catch (_) {
      _showSnack('Could not mark the salary as paid. Please try again.');
    }
  }

  Future<void> _edit() async {
    final item = _item;
    if (item == null) return;
    if (item.record.isPaid) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit a paid salary record?'),
          content: Text(
            'This record is already paid. Editing it changes the stored '
            'financial history. The change is not reversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('salary_edit_paid_confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Edit anyway'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalaryFormScreen(
          salaryService: widget.salaryService,
          existing: item.record,
        ),
      ),
    );
    await _load();
  }

  Future<void> _delete() async {
    final item = _item;
    if (item == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete salary record?'),
        content: Text(
          '${item.record.salaryRecordId} for ${item.employeeName} ('
          '${item.record.period.label}) will be permanently deleted. This '
          'cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('salary_delete_confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await widget.salaryService.deleteSalary(item.record.id);
        if (mounted) Navigator.of(context).pop();
      } catch (_) {
        _showSnack('Could not delete the salary record.');
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Salary Record')),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _item == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? 'Salary record is unavailable.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final item = _item!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.employeeName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            [
                              item.employeeCode,
                              if (item.designation != null &&
                                  item.designation!.isNotEmpty)
                                item.designation!,
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SalaryStatusChip(status: record.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.salaryRecordId} · ${record.period.label}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 24),
                _amountRow('Period', record.period.label),
                _amountRow('Base salary', record.baseSalary),
                _amountRow('Advance', record.advance),
                _amountRow('Deduction', record.deduction),
                _amountRow(
                  'Other adjustment',
                  _signed(record.otherAdjustment),
                ),
                _amountRow('Net payable', record.netAmount, bold: true),
                if (record.paymentDate != null)
                  _amountRow(
                    'Payment date',
                    Formatters.date(record.paymentDate!),
                  ),
                if (record.notes != null && record.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Notes: ${record.notes}'),
                ],
                const SizedBox(height: 12),
                if (record.isPaid)
                  Text(
                    'Paid on ${Formatters.date(record.paymentDate!)} — the '
                    'amounts on a paid record were set when it was paid.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  )
                else ...[
                  FilledButton.icon(
                    key: const Key('salary_mark_paid'),
                    onPressed: _markPaid,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark Paid'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('salary_record_delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete record'),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('salary_record_edit'),
                  onPressed: _edit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);
  }

  static String _signed(double value) =>
      value > 0 ? '+${Formatters.money(value)}' : Formatters.money(value);

  Widget _amountRow(String label, Object value, {bool bold = false}) {
    final text =
        value is double ? Formatters.money(value) : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: bold ? null : Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }
}
