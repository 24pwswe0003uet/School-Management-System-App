import 'package:flutter/material.dart';
import 'package:school_office_management/features/reports/domain/entities/report_category.dart';
import 'package:school_office_management/features/reports/domain/entities/report_definition.dart';
import 'package:school_office_management/features/reports/domain/entities/report_filter.dart';
import 'package:school_office_management/features/reports/domain/repositories/report_repository.dart';
import 'package:school_office_management/features/reports/presentation/widgets/report_menu_tile.dart';

/// Screen showing Student category reports.
class StudentReportsScreen extends StatefulWidget {
  const StudentReportsScreen({
    super.key,
    required this.reportRepository,
  });

  final ReportRepository reportRepository;

  @override
  State<StudentReportsScreen> createState() => _StudentReportsScreenState();
}

class _StudentReportsScreenState extends State<StudentReportsScreen> {
  ReportDefinition? _definition;
  List<ReportFilter> _appliedFilters = [];

  @override
  void initState() {
    super.initState();
    _loadDefinitions();
  }

  Future<void> _loadDefinitions() async {
    final definitions = await widget.reportRepository.listAllDefinitions();
    setState(() {
      _definition = definitions.firstWhere(
        (d) => d.category == ReportCategory.student,
        orElse: () => definitions.first,
      );
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
    if (_definition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_definition!.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a report:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildReportList(),
            const SizedBox(height: 24),
            _buildGenerateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildReportList() {
    final reports = _definition!.filters;
    if (reports.isEmpty) {
      return const Text('No reports available.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: reports.map<Widget>((ReportFilter filter) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ReportMenuTile(
            icon: _getIconForFilter(filter),
            color: _getColorForFilter(filter),
            title: filter.name,
            subtitle: '',
            onTap: () => _applyFilter(filter),
          ),
        );
      }).toList(),
    );
  }

  IconData _getIconForFilter(ReportFilter filter) {
    switch (filter.type) {
      case 'status':
        return Icons.person;
      case 'class-section':
        return Icons.class_;
      case 'date':
        return Icons.calendar_today;
      case 'date-range':
        return Icons.date_range;
      case 'month':
        return Icons.calendar_month;
      case 'year':
        return Icons.event;
      case 'category':
        return Icons.category;
      case 'entity':
        return Icons.business;
      default:
        return Icons.insert_chart;
    }
  }

  Color _getColorForFilter(ReportFilter filter) {
    return Colors.indigo;
  }

  void _applyFilter(ReportFilter filter) {
    _onFiltersChanged(_appliedFilters);
    _generateReport();
  }

  Widget _buildGenerateButton() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _generateReport,
          child: const Text('Generate Report'),
        ),
      ),
    );
  }
}
