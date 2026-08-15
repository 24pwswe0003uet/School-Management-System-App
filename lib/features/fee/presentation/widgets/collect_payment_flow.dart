import 'package:flutter/material.dart';

import '../../application/fee_service.dart';
import '../../domain/entities/fee_record.dart';
import '../receipt_screen.dart';
import 'payment_sheet.dart';

/// Shared collect-payment flow: opens the payment sheet and, when a payment is
/// recorded, opens the printable receipt for it.
Future<void> runCollectPaymentFlow(
  BuildContext context, {
  required FeeService feeService,
  required FeeRecord record,
}) async {
  final payment = await showPaymentSheet(
    context,
    feeService: feeService,
    record: record,
  );
  if (payment == null || !context.mounted) return;
  final receipt = feeService.lastReceipt;
  if (receipt == null) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReceiptScreen(receipt: receipt),
    ),
  );
}
