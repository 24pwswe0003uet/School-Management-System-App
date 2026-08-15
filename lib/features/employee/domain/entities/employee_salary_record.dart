/// Payment state of a salary record.
enum SalaryStatus {
  paid,
  pending;

  String get label => switch (this) {
    SalaryStatus.paid => 'Paid',
    SalaryStatus.pending => 'Pending',
  };

  static SalaryStatus fromDb(String value) =>
      value == 'paid' ? SalaryStatus.paid : SalaryStatus.pending;
}

/// One salary record for an employee: a monthly period and its payment state.
///
/// Balances are never recomputed here — [netAmount] is stored as recorded when
/// the salary was settled.
class EmployeeSalaryRecord {
  const EmployeeSalaryRecord({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.baseSalary,
    required this.advance,
    required this.deduction,
    required this.netAmount,
    required this.paymentDate,
    required this.status,
  });

  final int id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double baseSalary;
  final double advance;
  final double deduction;
  final double netAmount;
  final DateTime? paymentDate;
  final SalaryStatus status;
}
