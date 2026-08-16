import 'report_filter_option.dart';

/// Each [ReportFilter] specifies:
/// - The name shown in the UI
/// - The type of control to render (date, dropdown, entity-picker, etc.)
/// - Whether the field is required
/// - Optional predefined options (for dropdowns)
class ReportFilter {
  const ReportFilter({
    required this.name,
    required this.type,
    this.required = false,
    this.options,
  });

  /// The label shown in the filter UI.
  final String name;
  /// The type of control to render.
  /// Supported types: 'date', 'date-range', 'year', 'month', 'category', 'status',
  /// 'entity', 'class', 'section', 'employee', 'family'
  final String type;
  /// Whether the filter must have a value before generating the report.
  final bool required;
  /// Predefined options for dropdown or picker filters.
  /// Each option has a [value] (stored/DB value) and [label] (display text).
  final List<ReportFilterOption>? options;
}