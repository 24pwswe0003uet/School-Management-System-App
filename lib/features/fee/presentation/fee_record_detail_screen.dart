import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../application/fee_service.dart';
import '../domain/entities/fee_record_details.dart';
import '../domain/entities/fee_status.dart';
import '../domain/entities/payment_record.dart';
import 'receipt_screen.dart';
import 'widgets/collect_payment_flow.dart';
import 'widgets/fee_status_chip.dart';

/// Full view of one fee record: amounts, every payment, receipt access and the
/// controlled actions (pay, adjust, reverse).
class FeeRecordDetailScreen extends StatefulWidget {
  const FeeRecordDetailScreen({
    super.key,
    required this.feeService,
    required this.recordId,
  });

  final FeeService feeService;
  final int recordId;

  @override
  State<FeeRecordDetailScreen> createState() => _FeeRecordDetailScreenState();
}

class _FeeRecordDetailScreenState extends State<FeeRecordDetailScreen> {
  FeeRecordDetails? _details;
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
      final details = await widget.feeService.repository
          .getFeeRecordDetails(widget.recordId);
      if (!mounted) return;
      setState(() {
        _details = details;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Fee record could not be loaded.';
        _loading = false;
      });
    }
  }

  Future<void> _addPayment() async {
    final details = _details;
    if (details == null) return;
    await runCollectPaymentFlow(
      context,
      feeService: widget.feeService,
      record: details.record,
    );
    await _load();
  }

  Future<void> _adjust() async {
    final details = _details;
    if (details == null) return;
    final discount = TextEditingController(
      text: details.record.discount.toStringAsFixed(2),
    );
    final fine = TextEditingController(
      text: details.record.fine.toStringAsFixed(2),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust fee record'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('adjust_discount_field'),
              controller: discount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Discount',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('adjust_fine_field'),
              controller: fine,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Fine',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('adjust_save_button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final discountText = discount.text;
    final fineText = fine.text;
    discount.dispose();
    fine.dispose();
    if (confirmed != true || !mounted) return;
    final discountValue = double.tryParse(discountText.trim());
    final fineValue = double.tryParse(fineText.trim());
    if (discountValue == null || fineValue == null) {
      _showSnack('Discount and fine must be numbers.');
      return;
    }
    try {
      await widget.feeService.adjustFeeRecord(
        feeRecordId: widget.recordId,
        discount: discountValue,
        fine: fineValue,
      );
      await _load();
    } catch (_) {
      _showSnack(widget.feeService.errorMessage ?? 'Adjustment failed.');
    }
  }

  Future<void> _viewReceipt(PaymentRecord payment) async {
    final receipt = await widget.feeService.repository
        .receiptData(payment.id);
    if (!mounted) return;
    if (receipt == null) {
      _showSnack('Receipt data is unavailable.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReceiptScreen(receipt: receipt),
      ),
    );
  }

  Future<void> _reverse(PaymentRecord payment) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reverse payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment ${payment.paymentId} of '
                '${Formatters.money(payment.amount)} will be voided and the '
                'balance restored. This cannot be undone.',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('reverse_reason_field'),
                controller: reason,
                maxLines: 2,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Reason (required)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('reverse_confirm_button'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: reason.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: const Text('Reverse'),
            ),
          ],
        ),
      ),
    );
    final reasonText = reason.text;
    reason.dispose();
    if (confirmed != true || !mounted) return;
    try {
      await widget.feeService.reversePayment(
        paymentId: payment.id,
        reason: reasonText.trim(),
      );
      _showSnack('Payment reversed and balance restored.');
      await _load();
    } catch (_) {
      _showSnack(widget.feeService.errorMessage ?? 'Reversal failed.');
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
      appBar: AppBar(title: const Text('Fee Record')),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _details == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? 'Fee record is unavailable.',
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
    final details = _details!;
    final record = details.record;
    return ListView(
      padding: const EdgeInsets.all(16),
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
                            details.studentName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            [
                              details.studentId,
                              if (details.className != null)
                                'Class ${details.className}',
                              if (details.section != null) details.section,
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FeeStatusChip(status: record.status),
                  ],
                ),
                if (details.guardianName != null) ...[
                  const SizedBox(height: 4),
                  Text('Guardian: ${details.guardianName}'),
                ],
                const Divider(height: 24),
                _amountRow('Period', record.period.label, bold: true),
                _amountRow('Expected amount', record.expectedAmount),
                _amountRow('Discount', record.discount),
                _amountRow('Fine', record.fine),
                _amountRow('Net payable', record.netPayable, bold: true),
                _amountRow('Paid amount', record.paidAmount),
                _amountRow('Remaining', record.remainingAmount, bold: true),
                if (record.status != FeeStatus.paid) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('record_add_payment'),
                          onPressed: _addPayment,
                          icon: const Icon(Icons.payments_rounded),
                          label: const Text('Add Payment'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('record_adjust'),
                          onPressed: _adjust,
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Adjust'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Payments',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (details.payments.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No payments recorded yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          )
        else
          for (final payment in details.payments)
            _paymentCard(theme, payment),
      ],
    );
  }

  Widget _paymentCard(ThemeData theme, PaymentRecord payment) {
    final reversed = payment.status == PaymentStatus.reversed;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${Formatters.date(payment.paymentDate)} · '
                    '${payment.paymentId}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  Formatters.money(payment.amount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (payment.receiptNumber != null)
              Text(
                'Receipt ${payment.receiptNumber}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            if (payment.note != null)
              Text('Note: ${payment.note}', style: theme.textTheme.bodySmall),
            if (payment.createdByName != null)
              Text(
                'Recorded by ${payment.createdByName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            if (reversed) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reversed',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (payment.reverseReason != null)
                      Text(
                        'Reason: ${payment.reverseReason}',
                        style: theme.textTheme.bodySmall,
                      ),
                    if (payment.reversedByName != null)
                      Text(
                        'By ${payment.reversedByName}',
                        style: theme.textTheme.bodySmall,
                      ),
                    if (payment.reversedAt != null)
                      Text(
                        'On ${Formatters.date(payment.reversedAt!.toLocal())}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
            if (!reversed) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    key: Key('view_receipt_${payment.id}'),
                    onPressed: () => _viewReceipt(payment),
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('Receipt'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    key: Key('reverse_payment_${payment.id}'),
                    onPressed: () => _reverse(payment),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Reverse'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

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
                    color: bold
                        ? null
                        : Theme.of(context).colorScheme.outline,
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
