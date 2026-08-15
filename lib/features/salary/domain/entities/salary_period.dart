import '../../../../shared/utils/formatters.dart';

/// A monthly salary period, e.g. March 2026 (2026-03-01 .. 2026-03-31).
///
/// The database stores the period as the structured `period_start` /
/// `period_end` ISO dates (the same convention `fee_records` uses); this value
/// type gives the UI a typed `year` + `month` representation.
class SalaryPeriod {
  const SalaryPeriod({required this.year, required this.month});

  final int year;
  final int month;

  DateTime get startDate => DateTime(year, month, 1);
  DateTime get endDate => DateTime(year, month + 1, 0);

  /// First day of the month as `YYYY-MM-DD` (the record's period_start).
  String get startIso => _iso(startDate);

  /// Last day of the month as `YYYY-MM-DD` (the record's period_end).
  String get endIso => _iso(endDate);

  /// `YYYY-MM` prefix used to filter records within the month.
  String get monthKey =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  String get label => Formatters.monthYear(startDate);

  static SalaryPeriod fromDate(DateTime date) =>
      SalaryPeriod(year: date.year, month: date.month);

  /// Parses a `period_start` value like `2026-03-01` into its month period.
  static SalaryPeriod parse(String startIso) {
    final date = DateTime.tryParse(startIso);
    if (date == null) {
      throw FormatException('Invalid salary period: $startIso');
    }
    return fromDate(date);
  }

  static SalaryPeriod current() => fromDate(DateTime.now());

  static SalaryPeriod previous(SalaryPeriod period) {
    final date = DateTime(period.year, period.month, 1).subtract(
      const Duration(days: 1),
    );
    return fromDate(date);
  }

  static SalaryPeriod next(SalaryPeriod period) {
    final date = DateTime(period.year, period.month, 1).add(
      const Duration(days: 32),
    );
    return fromDate(date);
  }

  static String _iso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is SalaryPeriod && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}
