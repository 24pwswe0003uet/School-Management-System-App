import 'report_filter.dart';
import 'report_definition.dart';

/// The result of generating a [ReportDefinition].
///
/// Contains all information needed to render the report UI:
/// - Title and selected filters
/// - Summary metrics (for the Summary tab)
/// - Detailed records (for the Details tab)
/// - Generation timestamp
class ReportResult {
  const ReportResult({
    required this.definition,
    required this.filtersApplied,
    this.summary,
    this.details,
    required this.generatedAt,
  });

  /// The [ReportDefinition] that was generated.
  final ReportDefinition definition;
  /// The [ReportFilter] values that were applied.
  final List<ReportFilter> filtersApplied;
  /// Summary metrics rendered in the Summary tab.
  /// Optional — some reports may only have details.
  final Map<String, dynamic>? summary;
  /// Detailed records rendered in the Details tab.
  /// Optional — some reports may only have a summary.
  final List<Map<String, dynamic>>? details;
  /// When the report was generated.
  final DateTime generatedAt;

  /// Creates a [ReportResult] with summary and details.
  ReportResult.withBoth({
    required this.definition,
    required this.filtersApplied,
    required this.summary,
    required this.details,
  }) : generatedAt = DateTime.now();

  /// Creates a [ReportResult] with only summary.
  ReportResult.summaryOnly({
    required this.definition,
    required this.filtersApplied,
    required this.summary,
  })  : details = null,
        generatedAt = DateTime.now();

  /// Creates a [ReportResult] with only details.
  ReportResult.detailsOnly({
    required this.definition,
    required this.filtersApplied,
    required this.details,
  })  : summary = null,
        generatedAt = DateTime.now();
}