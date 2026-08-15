/// A real money transaction against a fee record.
///
/// Payments are never deleted in normal UI. A correction uses a controlled
/// reversal: the row is flagged `reversed` (with who/when/why) and the fee
/// record's balance is restored in the same transaction.
enum PaymentStatus {
  active,
  reversed;

  static PaymentStatus fromDb(String value) {
    return value == 'reversed' ? PaymentStatus.reversed : PaymentStatus.active;
  }
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.paymentId,
    required this.studentId,
    required this.feeRecordId,
    required this.amount,
    required this.paymentDate,
    this.receiptNumber,
    this.note,
    this.createdByUserId,
    this.createdByName,
    this.status = PaymentStatus.active,
    this.reversedAt,
    this.reversedByName,
    this.reverseReason,
  });

  final int id;
  final String paymentId;
  final int studentId;
  final int feeRecordId;
  final double amount;
  final DateTime paymentDate;
  final String? receiptNumber;
  final String? note;
  final int? createdByUserId;
  final String? createdByName;
  final PaymentStatus status;
  final DateTime? reversedAt;
  final String? reversedByName;
  final String? reverseReason;
}
