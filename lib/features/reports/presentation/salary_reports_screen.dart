import 'package:flutter/material.dart';
import '../domain/entities/report_category.dart';
import '../domain/repositories/report_repository.dart';
import 'unified_report_category_screen.dart';

/// Screen showing Salary category reports.
class SalaryReportsScreen extends StatelessWidget {
  const SalaryReportsScreen({
    super.key,
    required this.reportRepository,
  });

  final ReportRepository reportRepository;

  @override
  Widget build(BuildContext context) {
    return UnifiedReportCategoryScreen(
      reportRepository: reportRepository,
      category: ReportCategory.salary,
      categoryTitle: 'Salary Reports',
    );
  }
}
