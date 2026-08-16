import 'package:flutter/material.dart';
import 'package:school_office_management/features/reports/domain/entities/report_category.dart';
import 'package:school_office_management/features/reports/domain/entities/report_definition.dart';
import 'package:school_office_management/features/reports/domain/entities/report_filter.dart';
import 'package:school_office_management/features/reports/domain/repositories/report_repository.dart';
import 'package:school_office_management/features/reports/presentation/widgets/report_menu_tile.dart';

/// Screen showing Employee category reports.
class EmployeeReportsScreen extends StatefulWidget {
  const EmployeeReportsScreen({
    super.key,
    required this.reportRepository,
  });

  final ReportRepository reportRepository;

  @override
  State<EmployeeReportsScreen> createState() => _EmployeeReportsScreenState();
}

class _EmployeeReportsScreenState extends State<EmployeeReportsScreen> {
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
        (d) => d.category == ReportCategory.employee,
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

  void _applyFilter(ReportFilter filter) {
    _onFiltersChanged(_appliedFilters);
    _generateReport();
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
            icon: Icons.badge_rounded,
            color: Colors.purple,
            title: filter.name,
            subtitle: '',
            onTap: () => _applyFilter(filter),
          ),
        );
      }).toList(),
    );
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
