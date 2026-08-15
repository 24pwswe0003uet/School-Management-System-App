/// Everything a receipt needs to render — joined from the payment, fee record,
/// student and family at the time the receipt is produced.
class ReceiptData {
  const ReceiptData({
    required this.paymentId,
    required this.receiptNumber,
    required this.studentId,
    required this.studentName,
    required this.guardianName,
    required this.periodLabel,
    required this.expectedAmount,
    required this.discount,
    required this.fine,
    required this.netPayable,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentDate,
    this.paymentNote,
    this.createdByName,
    required this.isReversed,
  });

  final String paymentId;
  final String receiptNumber;
  final String studentId;
  final String studentName;
  final String? guardianName;
  final String periodLabel;
  final double expectedAmount;
  final double discount;
  final double fine;
  final double netPayable;
  final double paidAmount;
  final double remainingAmount;
  final DateTime paymentDate;
  final String? paymentNote;
  final String? createdByName;
  final bool isReversed;
}
