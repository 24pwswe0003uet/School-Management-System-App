import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../domain/entities/report_category.dart';
import '../domain/entities/report_definition.dart';
import '../domain/entities/report_filter.dart';
import '../domain/repositories/report_repository.dart';
import 'widgets/report_menu_tile.dart';

/// Reusable generic category reports screen replacing the 7 repetitive copies.
class UnifiedReportCategoryScreen extends StatefulWidget {
  const UnifiedReportCategoryScreen({
    super.key,
    required this.reportRepository,
    required this.category,
    required this.categoryTitle,
  });

  final ReportRepository reportRepository;
  final ReportCategory category;
  final String categoryTitle;

  @override
  State<UnifiedReportCategoryScreen> createState() => _UnifiedReportCategoryScreenState();
}

class _UnifiedReportCategoryScreenState extends State<UnifiedReportCategoryScreen> {
  ReportDefinition? _definition;
  List<ReportFilter> _appliedFilters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDefinitions();
  }

  Future<void> _loadDefinitions() async {
    final definitions = await widget.reportRepository.listAllDefinitions();
    if (!mounted) return;
    setState(() {
      _definition = definitions.firstWhere(
        (d) => d.category == widget.category,
        orElse: () => definitions.first,
      );
      _isLoading = false;
    });
  }

  void _onFiltersChanged(List<ReportFilter> filters) {
    setState(() => _appliedFilters = filters);
  }

  void _generateReport() {
    if (_definition == null) return;
    Navigator.pushNamed(
      context,
      '/reports/view',
      arguments: {
        'repository': widget.reportRepository,
        'definition': _definition!,
        'filters': _appliedFilters,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.categoryTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_definition == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.categoryTitle)),
        body: const Center(child: Text('No reports found for this category.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available ${widget.categoryTitle} Reports',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select a report below to apply filters and generate formatted summary or details.',
                  style: TextStyle(fontSize: 14, color: AppTheme.secondarySlate),
                ),
                const SizedBox(height: 20),
                _buildReportList(),
                const SizedBox(height: 24),
                Center(
                  child: FilledButton.icon(
                    onPressed: _generateReport,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Generate Report'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportList() {
    final reports = _definition!.filters;
    if (reports.isEmpty) {
      return const Text('No reports configured.');
    }
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: reports.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final filter = reports[index];
          return ReportMenuTile(
            icon: _getIconForFilter(filter),
            color: AppTheme.primaryNavy,
            title: filter.name,
            subtitle: 'Click to configure and view report',
            onTap: () {
              _onFiltersChanged([filter]);
              _generateReport();
            },
          );
        },
      ),
    );
  }

  IconData _getIconForFilter(ReportFilter filter) {
    switch (filter.type) {
      case 'status':
        return Icons.person_outline;
      case 'class-section':
        return Icons.class_outlined;
      case 'date':
        return Icons.calendar_today_outlined;
      case 'date-range':
        return Icons.date_range_outlined;
      case 'month':
        return Icons.calendar_month_outlined;
      case 'year':
        return Icons.event_outlined;
      case 'category':
        return Icons.category_outlined;
      case 'entity':
        return Icons.business_outlined;
      default:
        return Icons.insert_chart_outlined;
    }
  }
}
