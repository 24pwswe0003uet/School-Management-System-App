import 'report_category.dart';
import 'report_filter.dart';

/// Defines a single report available in the system.
///
/// Each [ReportDefinition] specifies:
/// - The category it belongs to
/// - Human-readable title and description
/// - The required filter fields and their expected types
/// - The type of result it produces
class ReportDefinition {
  const ReportDefinition({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.filters,
    required this.resultType,
  });

  final String id;
  final ReportCategory category;
  final String title;
  final String description;
  final List<ReportFilter> filters;
  final String resultType; // e.g. 'summary+details', 'table-only', 'chart-only'

  /// Creates a [ReportDefinition] for a student report.
  factory ReportDefinition.student({
    required String id,
    required String title,
    required String description,
    required List<ReportFilter> filters,
  }) =>
      ReportDefinition(
        id: id,
        category: ReportCategory.student,
        title: title,
        description: description,
        filters: filters,
        resultType: 'summary+details',
      );

  /// Creates a [ReportDefinition] for a fee report.
  factory ReportDefinition.fee({
    required String id,
    required String title,
    required String description,
    required List<ReportFilter> filters,
  }) =>
      ReportDefinition(
        id: id,
        category: ReportCategory.fee,
        title: title,
        description: description,
        filters: filters,
        resultType: 'summary+details',
      );

  /// Creates a [ReportDefinition] for a financial summary report.
  factory ReportDefinition.financial({
    required String id,
    required String title,
    required String description,
    required List<ReportFilter> filters,
  }) =>
      ReportDefinition(
        id: id,
        category: ReportCategory.financial,
        title: title,
        description: description,
        filters: filters,
        resultType: 'summary+details',
      );

  /// Creates a [ReportDefinition] for an employee report.
  factory ReportDefinition.employee({
    required String id,
    required String title,
    required String description,
    required List<ReportFilter> filters,
  }) =>
      ReportDefinition(
        id: id,
        category: ReportCategory.employee,
        title: title,
        description: description,
        filters: filters,
        resultType: 'summary+details',
      );

  /// Creates a [ReportDefinition] for a salary report.
  factory ReportDefinition.salary({
    required String id,
    required String title,
    required String description,
    required List<ReportFilter> filters,
  }) =>
      ReportDefinition(
        id: id,
        category: ReportCategory.salary,
        title: title,
        description: description,
        filters: filters,
        resultType: 'summary+details',
      );

  /// Creates a [ReportDefinition] for an admission report.
  factory ReportDefinition.admission({
    required String id,
    required String title,
    required String description,
    required List<ReportFilter> filters,
  }) =>
      ReportDefinition(
        id: id,
        category: ReportCategory.admission,
        title: title,
        description: description,
        filters: filters,
        resultType: 'summary+details',
      );

  /// Creates a [ReportDefinition] for an expense report.
  factory ReportDefinition.expense({
    required String id,
    required String title,
    required String description,
    required List<ReportFilter> filters,
  }) =>
      ReportDefinition(
        id: id,
        category: ReportCategory.expense,
        title: title,
        description: description,
        filters: filters,
        resultType: 'summary+details',
      );
}