/// A student's fee record with its payment sum — the rows the fee history list
/// displays. The Fee module will create these records; here they are read-only.
class StudentFeeHistoryItem {
  const StudentFeeHistoryItem({
    required this.feeRecordId,
    required this.feeRecordCode,
    required this.periodStart,
    required this.periodEnd,
    required this.expected,
    required this.paid,
    required this.status,
  });

  final int feeRecordId;
  final String feeRecordCode;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double expected;
  final double paid;
  final String status;

  double get due => expected - paid < 0 ? 0 : expected - paid;
}
