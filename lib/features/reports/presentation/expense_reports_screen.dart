import 'package:flutter/material.dart';
import '../domain/entities/report_category.dart';
import '../domain/repositories/report_repository.dart';
import 'unified_report_category_screen.dart';

/// Screen showing Expense category reports in the Reports module.
class ExpenseReportsScreen extends StatelessWidget {
  const ExpenseReportsScreen({
    super.key,
    required this.reportRepository,
  });

  final ReportRepository reportRepository;

  @override
  Widget build(BuildContext context) {
    return UnifiedReportCategoryScreen(
      reportRepository: reportRepository,
      category: ReportCategory.expense,
      categoryTitle: 'Expense Reports',
    );
  }
}
