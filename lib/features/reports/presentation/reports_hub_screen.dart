import 'package:flutter/material.dart';

import '../domain/entities/report_category.dart';
import '../domain/entities/report_definition.dart';
import '../domain/repositories/report_repository.dart';
import 'widgets/report_menu_tile.dart';

/// The main Reports Hub screen showing 7 category cards.
///
/// Users select a category, then choose a report, apply filters, and generate.
class ReportsHubScreen extends StatefulWidget {
  const ReportsHubScreen({
    super.key,
    required this.reportRepository,
  });

  final ReportRepository reportRepository;

  @override
  State<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends State<ReportsHubScreen> {
  Map<ReportCategory, int> _categoryCounts = {};

  @override
  void initState() {
    super.initState();
    _loadDefinitions();
  }

  Future<void> _loadDefinitions() async {
    final definitions = await widget.reportRepository.listAllDefinitions();
    setState(() {
      _categoryCounts = _computeCategoryCounts(definitions);
    });
  }

  static Map<ReportCategory, int> _computeCategoryCounts(
      List<ReportDefinition> definitions) {
    final counts = <ReportCategory, int>{};
    for (final def in definitions) {
      counts[def.category] = (counts[def.category] ?? 0) + 1;
    }
    return counts;
  }

  // Category card data per the plan
  static const _categoryCards = [
    ReportMenuTileData(
      category: ReportCategory.student,
      title: 'Student',
      subtitle: '6 reports available',
      icon: Icons.school_rounded,
      color: Colors.indigo,
    ),
    ReportMenuTileData(
      category: ReportCategory.admission,
      title: 'Admission',
      subtitle: '3 reports available',
      icon: Icons.assignment_turned_in_rounded,
      color: Colors.teal,
    ),
    ReportMenuTileData(
      category: ReportCategory.fee,
      title: 'Fee',
      subtitle: '8 reports available',
      icon: Icons.payments_rounded,
      color: Colors.green,
    ),
    ReportMenuTileData(
      category: ReportCategory.employee,
      title: 'Employee',
      subtitle: '4 reports available',
      icon: Icons.badge_rounded,
      color: Colors.purple,
    ),
    ReportMenuTileData(
      category: ReportCategory.salary,
      title: 'Salary',
      subtitle: '6 reports available',
      icon: Icons.monetization_on_rounded,
      color: Colors.deepOrange,
    ),
    ReportMenuTileData(
      category: ReportCategory.expense,
      title: 'Expense',
      subtitle: '4 reports available',
      icon: Icons.receipt_long_rounded,
      color: Colors.red,
    ),
    ReportMenuTileData(
      category: ReportCategory.financial,
      title: 'Financial',
      subtitle: '1 report available',
      icon: Icons.analytics_rounded,
      color: Colors.blue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Apply filters',
            onPressed: () {
              // TODO: Implement filter application
            },
          ),
        ],
      ),
      body: _categoryCounts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Select a category to view available reports:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final card = _categoryCards[index];
                      return ReportMenuTile(
                        key: ValueKey(card.category),
                        icon: card.icon,
                        color: card.color,
                        title: card.title,
                        subtitle: card.subtitle,
                        onTap: () =>
                            _navigateToCategoryReports(context, card.category),
                      );
                    },
                    childCount: _categoryCards.length,
                  ),
                ),
              ],
            ),
    );
  }

  void _navigateToCategoryReports(
      BuildContext context, ReportCategory category) {
    // Navigate to the category-specific reports screen
    // Each category screen will show its available reports with filters
    final routeName = '/reports/${_routeNameFromCategory(category)}';
    Navigator.pushNamed(context, routeName);
  }

  String _routeNameFromCategory(ReportCategory category) {
    switch (category) {
      case ReportCategory.student:
        return 'student';
      case ReportCategory.admission:
        return 'admission';
      case ReportCategory.fee:
        return 'fee';
      case ReportCategory.employee:
        return 'employee';
      case ReportCategory.salary:
        return 'salary';
      case ReportCategory.expense:
        return 'expense';
      case ReportCategory.financial:
        return 'financial';
    }
  }
}

class ReportMenuTileData {
  const ReportMenuTileData({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final ReportCategory category;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}