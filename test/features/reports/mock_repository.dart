import 'package:school_office_management/features/reports/domain/entities/report_category.dart';
import 'package:school_office_management/features/reports/domain/entities/report_definition.dart';
import 'package:school_office_management/features/reports/domain/entities/report_filter.dart';
import 'package:school_office_management/features/reports/domain/entities/report_filter_option.dart';
import 'package:school_office_management/features/reports/domain/entities/report_result.dart';
import 'package:school_office_management/features/reports/domain/entities/financial_summary.dart';
import 'package:school_office_management/features/reports/domain/repositories/report_repository.dart';

/// Mock report repository for testing.
class MockReportRepository implements ReportRepository {
  @override
  Future<FinancialSummary> generateFinancialSummary({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    return FinancialSummary(
      feeIncomeCharged: 100000,
      feeIncomeCollected: 85000,
      salaryExpenses: 45000,
      otherExpenses: 20000,
      netPosition: 100000 - 85000 - 45000 - 20000,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }

  @override
  Future<ReportResult> generateReport({
    required ReportDefinition definition,
    required List<ReportFilter> filtersApplied,
  }) async {
    // Mock implementation - returns a basic report result
    return ReportResult(
      definition: definition,
      summary: {
        'record_count': 10,
        'total_amount': 5000.00,
      },
      details: [],
      filtersApplied: filtersApplied,
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<ReportDefinition>> listAllDefinitions() async {
    return [
      ReportDefinition.student(
        id: 'student-all',
        title: 'All Students',
        description: 'List of all students',
        filters: [
          ReportFilter(name: 'Status', type: 'status', options: [
            ReportFilterOption(value: 'active', label: 'Active'),
            ReportFilterOption(value: 'left', label: 'Left'),
            ReportFilterOption(value: 'transferred', label: 'Transferred'),
          ]),
        ],
      ),
      ReportDefinition.student(
        id: 'student-by-class',
        title: 'Students by Class',
        description: 'Student count per class',
        filters: [
          ReportFilter(name: 'Class', type: 'class', required: true),
        ],
      ),
      ReportDefinition.admission(
        id: 'admission-by-date',
        title: 'Admissions by Date',
        description: 'Admissions within a date range',
        filters: [
          ReportFilter(name: 'Date Range', type: 'date-range', required: true),
        ],
      ),
      ReportDefinition.fee(
        id: 'fee-daily-collection',
        title: 'Daily Collection',
        description: 'Fee collection for a specific date',
        filters: [
          ReportFilter(name: 'Date', type: 'date', required: true),
        ],
      ),
      ReportDefinition.fee(
        id: 'fee-outstanding',
        title: 'Outstanding Fees',
        description: 'Total outstanding fee amount',
        filters: [
          ReportFilter(name: 'Status', type: 'status', options: [
            ReportFilterOption(value: 'outstanding', label: 'Outstanding'),
          ]),
        ],
      ),
      ReportDefinition.employee(
        id: 'employee-by-category',
        title: 'Employees by Category',
        description: 'Employee count per category',
        filters: [
          ReportFilter(name: 'Category', type: 'category', required: true),
        ],
      ),
      ReportDefinition.salary(
        id: 'salary-paid',
        title: 'Paid Salary',
        description: 'Total paid salary for a period',
        filters: [
          ReportFilter(name: 'Status', type: 'status', options: [
            ReportFilterOption(value: 'paid', label: 'Paid'),
          ]),
          ReportFilter(name: 'Month', type: 'month', required: true),
        ],
      ),
      ReportDefinition.expense(
        id: 'expense-monthly',
        title: 'Monthly Expenses',
        description: 'Total expenses for a month',
        filters: [
          ReportFilter(name: 'Month', type: 'month', required: true),
        ],
      ),
      ReportDefinition.financial(
        id: 'financial-summary',
        title: 'Financial Summary',
        description: 'Fee Income, Salary Expenses, Other Expenses, Net Position',
        filters: const [
          ReportFilter(name: 'Start Date', type: 'date', required: true),
          ReportFilter(name: 'End Date', type: 'date', required: true),
        ],
      ),
    ];
  }

  @override
  Future<ReportDefinition> getDefinitionByCategoryAndIndex({
    required ReportCategory category,
    required int index,
  }) async {
    final definitions = await listAllDefinitions();
    return definitions.indexWhere((d) => d.category == category) != -1
        ? definitions.firstWhere((d) => d.category == category)
        : definitions.first;
  }

  @override
  Future<ReportResult> generateStudentReport({
    required ReportDefinition definition,
    required List<ReportFilter> filtersApplied,
  }) async {
    final details = <Map<String, dynamic>>[
      {
        'id': '1',
        'student_id': 'S001',
        'name': 'John Smith',
        'gender': 'Male',
        'class': '10',
        'section': 'A',
        'status': 'active',
      },
      {
        'id': '2',
        'student_id': 'S002',
        'name': 'Jane Doe',
        'gender': 'Female',
        'class': '11',
        'section': 'B',
        'status': 'active',
      },
    ];
    return ReportResult.detailsOnly(
      definition: definition,
      filtersApplied: filtersApplied,
      details: details,
    );
  }

  @override
  Future<ReportResult> generateAdmissionReport({
    required ReportDefinition definition,
    required List<ReportFilter> filtersApplied,
  }) async {
    final details = <Map<String, dynamic>>[
      {
        'id': '1',
        'admission_id': 'ADM001',
        'admission_date': DateTime(2024, 1, 15).toIso8601String(),
        'class': '10',
        'section': 'A',
        'admission_number': 'ADM-001',
        'student_name': 'John Smith',
      },
    ];
    return ReportResult.detailsOnly(
      definition: definition,
      filtersApplied: filtersApplied,
      details: details,
    );
  }

  @override
  Future<ReportResult> generateFeeReport({
    required ReportDefinition definition,
    required List<ReportFilter> filtersApplied,
  }) async {
    final details = <Map<String, dynamic>>[
      {
        'period_start': '2024-01-01',
        'period_end': '2024-01-31',
        'expected_amount': 50000,
        'paid_amount': 45000,
        'remaining_amount': 5000,
        'status': 'paid',
      },
    ];
    return ReportResult.detailsOnly(
      definition: definition,
      filtersApplied: filtersApplied,
      details: details,
    );
  }

  @override
  Future<ReportResult> generateEmployeeReport({
    required ReportDefinition definition,
    required List<ReportFilter> filtersApplied,
  }) async {
    final details = <Map<String, dynamic>>[
      {
        'id': '1',
        'employee_id': 'E001',
        'name': 'John Doe',
        'designation': 'Teacher',
        'category': 'Full-time',
      },
    ];
    return ReportResult.detailsOnly(
      definition: definition,
      filtersApplied: filtersApplied,
      details: details,
    );
  }

  @override
  Future<ReportResult> generateSalaryReport({
    required ReportDefinition definition,
    required List<ReportFilter> filtersApplied,
  }) async {
    return ReportResult.summaryOnly(
      definition: definition,
      filtersApplied: filtersApplied,
      summary: {
        'total_amount': 45000,
        'record_count': 5,
      },
    );
  }

  @override
  Future<ReportResult> generateExpenseReport({
    required ReportDefinition definition,
    required List<ReportFilter> filtersApplied,
  }) async {
    final details = <Map<String, dynamic>>[
      {
        'id': '1',
        'expense_id': 'EXP001',
        'date': DateTime(2024, 1, 15).toIso8601String(),
        'category': 'Salary',
        'amount': 5000,
        'description': 'Monthly salary advance',
      },
    ];
    return ReportResult.detailsOnly(
      definition: definition,
      filtersApplied: filtersApplied,
      details: details,
    );
  }
}