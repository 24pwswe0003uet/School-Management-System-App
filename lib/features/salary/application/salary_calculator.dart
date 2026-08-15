import '../../../shared/utils/formatters.dart';

/// Central business logic for salary money math.
///
/// Net salary is never entered or stored by hand — every write computes it
/// through [netPayable] here so the formula stays in one place:
///
///   net = base - advance - deduction + otherAdjustment
///
/// Money follows the app-wide convention (double, rounded to 2 decimals).
/// A negative raw result is clamped to zero — the UI surfaces this via
/// [isClamped] so the operator is never silently short-changed.
abstract final class SalaryCalculator {
  /// Rounds a monetary component to 2 decimals, matching [Formatters.money].
  static double round(double value) => Formatters.roundTo(value, 2);

  /// The unclamped raw result, rounded.
  static double raw({
    required double base,
    required double advance,
    required double deduction,
    required double otherAdjustment,
  }) {
    return round(base - advance - deduction + otherAdjustment);
  }

  /// True when the components would leave a negative net (which gets clamped).
  static bool isClamped({
    required double base,
    required double advance,
    required double deduction,
    required double otherAdjustment,
  }) {
    return base - advance - deduction + otherAdjustment < 0;
  }

  /// The net payable for a record: `base - advance - deduction + adjustment`,
  /// rounded and never negative.
  static double netPayable({
    required double base,
    required double advance,
    required double deduction,
    required double otherAdjustment,
  }) {
    final value = raw(
      base: base,
      advance: advance,
      deduction: deduction,
      otherAdjustment: otherAdjustment,
    );
    return value < 0 ? 0 : value;
  }
}
