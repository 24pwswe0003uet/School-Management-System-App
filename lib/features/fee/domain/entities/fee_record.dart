import 'fee_period.dart';
import 'fee_status.dart';

/// One charge for a student and a monthly period.
///
/// Balances are never recomputed by readers — [paidAmount], [remainingAmount]
/// and [status] are updated transactionally whenever a payment is recorded or
/// reversed, or the record is adjusted. `net_payable = expected - discount +
/// fine` is also maintained by the repository.
class FeeRecord {
  const FeeRecord({
    required this.id,
    required this.feeRecordId,
    required this.studentId,
    required this.period,
    required this.expectedAmount,
    required this.discount,
    required this.fine,
    required this.netPayable,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
  });

  final int id;
  final String feeRecordId;
  final int studentId;
  final FeePeriod period;
  final double expectedAmount;
  final double discount;
  final double fine;
  final double netPayable;
  final double paidAmount;
  final double remainingAmount;
  final FeeStatus status;
}
