/// Payment state of a salary record.
enum SalaryStatus {
  paid,
  pending;

  String get label => switch (this) {
    SalaryStatus.paid => 'Paid',
    SalaryStatus.pending => 'Pending',
  };

  String get dbValue => switch (this) {
    SalaryStatus.paid => 'paid',
    SalaryStatus.pending => 'pending',
  };

  static SalaryStatus fromDb(String value) =>
      value == 'paid' ? SalaryStatus.paid : SalaryStatus.pending;
}
