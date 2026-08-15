import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../shared/utils/formatters.dart';
import '../../application/fee_service.dart';
import '../../domain/entities/fee_record.dart';
import '../../domain/entities/payment_record.dart';

/// Opens a bottom sheet that captures a payment against [record].
///
/// Returns the recorded [PaymentRecord], or null when the user cancels.
Future<PaymentRecord?> showPaymentSheet(
  BuildContext context, {
  required FeeService feeService,
  required FeeRecord record,
}) {
  return showModalBottomSheet<PaymentRecord>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PaymentSheet(feeService: feeService, record: record),
  );
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.feeService, required this.record});

  final FeeService feeService;
  final FeeRecord record;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _receiptController;
  final TextEditingController _noteController = TextEditingController();
  late DateTime _date;
  bool _submitting = false;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    final remaining = widget.record.remainingAmount;
    _amountController = TextEditingController(
      text: remaining > 0 ? remaining.toStringAsFixed(2) : '',
    );
    _date = DateTime.now();
    _receiptController = TextEditingController();
    widget.feeService.repository.nextReceiptNumber().then((value) {
      if (mounted && _receiptController.text.isEmpty) {
        _receiptController.text = value;
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _receiptController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    final remaining = widget.record.remainingAmount;
    if (amount == null || amount <= 0) {
      setState(() => _fieldError = 'Enter an amount greater than zero.');
      return;
    }
    if (amount > remaining + 0.0001) {
      setState(
        () => _fieldError =
            'Only ${Formatters.money(remaining)} remains for this period.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _fieldError = null;
    });
    try {
      final payment = await widget.feeService.collectPayment(
        feeRecordId: widget.record.id,
        studentId: widget.record.studentId,
        amount: amount,
        paymentDate: _date,
        receiptNumber: _receiptController.text.trim().isEmpty
            ? null
            : _receiptController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(payment);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              widget.feeService.errorMessage ??
                  'The payment could not be recorded.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Collect Payment',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.record.period.label} — '
              '${Formatters.money(widget.record.remainingAmount)} remaining',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('payment_amount_field'),
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${AppConfig.currencySymbol} ',
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: _fieldError,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              key: const Key('payment_date_field'),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Payment date',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: Text(Formatters.date(_date)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('payment_receipt_field'),
              controller: _receiptController,
              decoration: const InputDecoration(
                labelText: 'Receipt number',
                hintText: 'Leave blank to auto-generate',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('payment_note_field'),
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('payment_submit_button'),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Record Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
