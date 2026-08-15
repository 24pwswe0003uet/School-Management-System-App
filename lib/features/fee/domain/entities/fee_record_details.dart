import 'fee_record.dart';
import 'payment_record.dart';

/// A fee record with its full context and every payment (including reversed
/// ones, so the payment history always tells the whole story).
class FeeRecordDetails {
  const FeeRecordDetails({
    required this.record,
    required this.studentId,
    required this.studentName,
    this.guardianName,
    this.className,
    this.section,
    required this.payments,
  });

  final FeeRecord record;
  final String studentId;
  final String studentName;
  final String? guardianName;
  final String? className;
  final String? section;
  final List<PaymentRecord> payments;
}
