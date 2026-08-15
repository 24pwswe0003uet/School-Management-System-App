import '../../core/config/app_config.dart';

/// Dependency-free formatting helpers used across screens.
abstract final class Formatters {
  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Formats a monetary amount, e.g. `Rs 12,500` (or `Rs 0` for zero).
  static String money(double value, {String? symbol}) {
    final currency = symbol ?? AppConfig.currencySymbol;
    return '$currency ${_thousands(roundTo(value, 2))}';
  }

  /// Rounds to 2 decimals and trims trailing zeros for display.
  static double roundTo(double value, int places) {
    final factor = _tenPow(places);
    return (value * factor).roundToDouble() / factor;
  }

  static String _thousands(double value) {
    final isNegative = value < 0;
    final parts = value.abs().toStringAsFixed(2).split('.');
    final digits = parts[0];
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    final decimals = parts[1];
    final trimmed = decimals.endsWith('00') ? '' : '.$decimals';
    return '${isNegative ? '-' : ''}$buffer$trimmed';
  }

  static double _tenPow(int places) {
    var result = 1.0;
    for (var i = 0; i < places; i++) {
      result *= 10;
    }
    return result;
  }

  /// Formats a date like `14 Aug 2026`.
  static String date(DateTime date) {
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  /// Formats a date like `Fri, 14 Aug 2026`.
  static String dateWithWeekday(DateTime date) {
    final weekday = _weekdays[date.weekday - 1];
    return '$weekday, ${Formatters.date(date)}';
  }

  /// Formats a month like `Aug 2026`.
  static String monthYear(DateTime date) {
    return '${_months[date.month - 1]} ${date.year}';
  }
}
