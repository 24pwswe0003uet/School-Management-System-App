import 'fee_period.dart';

/// Total collected in a month from active (non-reversed) payments.
class MonthlyCollectionReport {
  const MonthlyCollectionReport({
    required this.period,
    required this.collected,
    required this.paymentCount,
  });

  final FeePeriod period;
  final double collected;
  final int paymentCount;
}
