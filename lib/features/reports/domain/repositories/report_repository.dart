import '../entities/financial_summary.dart';
import '../entities/report_category.dart';
import '../entities/report_definition.dart';
import '../entities/report_filter.dart';
import '../entities/report_result.dart';

/// Abstract interface for all report generation operations.
///
/// Each method corresponds to a specific report defined in [ReportDefinition].
/// Implementations in [ReportRepositoryImpl] execute database-level aggregate
/// queries (SUM, COUNT, GROUP BY, JOIN) and return typed [ReportResult] objects.
abstract interface class ReportRepository {
  /// Generates a report based on the given definition and applied filters.
  Future<ReportResult> generateReport({
    required ReportDefinition definition,
    required List<ReportFilter> filtersApplied,
  });

  /// Generates a student report based on the given definition and applied filters.
  Future<ReportResult> generateStudentReport({
    required ReportDefinition definition,
    required List<ReportFilter> filtersApplied,
  });

  /// Generates an admission report based on the given definition and applied filters.
  Future<ReportResult> generateAdmissionReport({
    required ReportDefinition definition,
    required List<ReportFilter> filtersApplied,
  });

  /// Generates a fee report based on the given definition and applied filters.
  Future<ReportResult> generateFeeReport({
    required ReportDefinition definition,
    required List<ReportFilter> filtersApplied,
  });

  /// Generates an employee report based on the given definition and applied filters.
  Future<ReportResult> generateEmployeeReport({
    required ReportDefinition definition,
    required List<ReportFilter> filtersApplied,
  });

  /// Generates a salary report based on the given definition and applied filters.
  Future<ReportResult> generateSalaryReport({
    required ReportDefinition definition,
    required List<ReportFilter> filtersApplied,
  });

  /// Generates an expense report based on the given definition and applied filters.
  Future<ReportResult> generateExpenseReport({
    required ReportDefinition definition,
    required List<ReportFilter> filtersApplied,
  });

  /// Generates a financial summary report for a given date range.
  Future<FinancialSummary> generateFinancialSummary({
    required DateTime periodStart,
    required DateTime periodEnd,
  });

  /// Returns a list of all [ReportDefinition]s available in the system.
  /// Used by the ReportsHubScreen to populate the category cards.
  Future<List<ReportDefinition>> listAllDefinitions();

  /// Returns the [ReportDefinition] for a given [ReportCategory] and report index.
  Future<ReportDefinition> getDefinitionByCategoryAndIndex({
    required ReportCategory category,
    required int index,
  });
}