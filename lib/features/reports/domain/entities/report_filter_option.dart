/// A predefined option for a [ReportFilter].
///
/// The [value] is the SQL-friendly value (e.g. 'active', '2026-08', a student ID).
/// The [label] is the display text shown to the user.
class ReportFilterOption {
  const ReportFilterOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}