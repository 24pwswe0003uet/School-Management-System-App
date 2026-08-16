import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:school_office_management/shared/extensions/string_extensions.dart';

import '../domain/entities/report_definition.dart';
import '../domain/entities/report_filter.dart';
import '../domain/entities/report_result.dart';
import '../domain/repositories/report_repository.dart';
import '../../settings/domain/services/settings_service.dart';
import 'package:school_office_management/features/reports/domain/services/report_export_service.dart';

/// Generic screen showing a report's Summary and Details tabs.
///
/// After filters are applied, this screen displays:
/// - Tab 1: Summary — key metrics from the report's summary map
/// - Tab 2: Details — the actual records returned by the report
/// - Bottom action: Export to Excel
class ReportViewScreen extends StatefulWidget {
  const ReportViewScreen({
    super.key,
    required this.reportRepository,
    required this.definition,
    required this.filtersApplied,
    required this.exportService,
    required this.settingsService,
  });

  final ReportRepository reportRepository;
  final ReportDefinition definition;
  final List<ReportFilter> filtersApplied;
  final ReportExportService exportService;
  final SettingsService settingsService;

  @override
  State<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends State<ReportViewScreen> {
  ReportResult? _result;
  bool _isLoading = false;
  String? _error;
  bool _showExport = false;

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await widget.reportRepository.generateReport(
        definition: widget.definition,
        filtersApplied: widget.filtersApplied,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
        _showExport = _result!.details?.isNotEmpty ?? false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'The report could not be generated: $e';
        _isLoading = false;
      });
    }
  }

  // Helper: build summary metric card
  Widget _buildMetricCard(IconData icon, String label, dynamic value,
      {Color? color, required BuildContext context}) {
    final theme = Theme.of(context);
    final formattedValue = _formatValue(value);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color ?? theme.colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedValue,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is int || value is double) {
      return 'Rs ${value.toStringAsFixed(2)}';
    }
    if (value is String) return value;
    return value.toString();
  }

  // Helper: build summary section from ReportResult.summary map
  Widget _buildSummarySection(BuildContext context) {
    if (_result?.summary == null) {
      return _buildEmptySummary(context);
    }

    final summary = _result!.summary!;
    final theme = Theme.of(context);

    // Extract common metrics
    final recordCount =
        summary['record_count'] ?? summary['total'] ?? summary['count'] ?? 0;
    final generatedAt = _result!.generatedAt;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Report header info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.insert_chart_rounded,
                        color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _result!.definition.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: theme.colorScheme.outline, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Generated: ${DateFormat.jm().format(generatedAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                if (_result!.filtersApplied.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Applied Filters:',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    children: _result!.filtersApplied.map((filter) {
                      return Chip(
                        label: Text(filter.name.replaceAll(' ', '\n')),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                      );
                    }).toList(),
                  ),
                ],
                const Divider(),
                // Key metrics based on result type
                _buildMetricCard(
                  Icons.school_rounded,
                  'Record Count',
                  recordCount,
                  context: context,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Metric cards grid
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _buildMetricCardsFromSummary(summary, theme, context),
        ),
      ],
    );
  }

  List<Widget> _buildMetricCardsFromSummary(
      Map<String, dynamic> summary, ThemeData theme, BuildContext context) {
    final List<Widget> cards = [];

    // Add metric cards based on what's available in the summary
    final hasMoney =
        summary.keys.any((k) => k.toString().toLowerCase().contains('money') ||
            k.toString().toLowerCase().contains('amount') ||
            k.toString().toLowerCase().contains('total'));

    if (hasMoney) {
      // Try to find currency-related fields
      final moneyFields = <String>[];
      summary.forEach((key, value) {
        if (key.toString().toLowerCase().contains('income') ||
            key.toString().toLowerCase().contains('expense') ||
            key.toString().toLowerCase().contains('salary') ||
            key.toString().toLowerCase().contains('fee') ||
            key.toString().toLowerCase().contains('paid') ||
            key.toString().toLowerCase().contains('outstanding') ||
            key.toString().toLowerCase().contains('net')) {
          moneyFields.add(key);
        }
      });

      // Add up to 4 money metric cards
      for (int i = 0; i < moneyFields.length && i < 4; i++) {
        final key = moneyFields[i];
        final value = summary[key];
        final label = key.split('_').map((part) =>
            part[0].toUpperCase() + part.substring(1)).join(' ');
        cards.add(_buildMetricCard(
          _getIconForKey(key),
          label,
          value,
          context: context,
        ));
      }
    } else {
      // Generic record count card
      cards.add(_buildMetricCard(
        Icons.numbers,
        'Record Count',
        summary['record_count'] ?? summary['total'] ?? 0,
        context: context,
      ));
    }

    return cards;
  }

  IconData _getIconForKey(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('income') || lower.contains('fee')) return Icons.remove_circle;
    if (lower.contains('expense')) return Icons.add_circle;
    if (lower.contains('salary')) return Icons.schedule;
    if (lower.contains('net')) return Icons.remove;
    return Icons.numbers;
  }

  Widget _buildEmptySummary(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No summary available for this report.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This report provides detailed records only.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  // Navigate back or show details
                  {},
              child: const Text('View Details'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper: build details data table or list view
  Widget _buildDetailsSection(BuildContext context) {
    if (_result?.details == null || _result!.details!.isEmpty) {
      return _buildEmptyDetails(context);
    }

    final details = _result!.details!;
    final theme = Theme.of(context);
    final firstRow = details.first;

    // Determine column layout from first record
    final columns = <String>[];
    firstRow.forEach((key, value) {
      columns.add(key);
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns.map<DataColumn>((String label) {
          return DataColumn(
            label: Text(
              label.replaceAll('_', ' ').capitalizeFirst(),
              style: theme.textTheme.bodySmall,
            ),
          );
        }).toList(),
        rows: details.map<DataRow>((Map<String, dynamic> row) {
          return DataRow(
            cells: columns.map<DataCell>((String column) {
              final value = row[column];
              return DataCell(
                Text(_formatDetailsValue(value, column),
                    style: theme.textTheme.bodySmall),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  String _formatDetailsValue(dynamic value, String column) {
    if (value == null) return '';
    final lower = column.toLowerCase();
    // Currency columns
    if (lower.contains('amount') ||
        lower.contains('price') ||
        lower.contains('total') ||
        lower.contains('paid') ||
        lower.contains('fee') ||
        lower.contains('salary') ||
        lower.contains('expense') ||
        lower.contains('net') ||
        lower.contains('income')) {
      if (value is num) {
        return 'Rs ${value.toStringAsFixed(2)}';
      }
      return value.toString();
    }
    // Date columns
    if (lower.contains('date') || lower.contains('day') ||
        lower.contains('period') || lower.contains('start') ||
        lower.contains('end') || lower.contains('admission')) {
      if (value is DateTime) {
        return DateFormat.yMMMd().format(value);
      }
      return value.toString();
    }
    // Text columns
    return value.toString();
  }

  Widget _buildEmptyDetails(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.remove_circle_outline,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No records found.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The selected filters returned no records. '
              'Try adjusting the filter values.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport() async {
    if (_result == null) return;
    final path = await widget.exportService.exportReport(
      _result!,
      schoolName: widget.settingsService.profile.schoolName,
    );
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report exported successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export cancelled or failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_result?.definition.title ?? 'Report'),
        actions: [
          // Show applied filters as chips in app bar
          if (_result?.filtersApplied.isNotEmpty == true) ...[
            Wrap(
              spacing: 4,
              children: _result!.filtersApplied.map((filter) {
                return FilterChip(
                  label: Text(filter.name.replaceAll(' ', '\n')),
                  selected: false,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  onSelected: (bool selected) {},
                );
              }).toList(),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to Excel',
            onPressed: _showExport || _result != null ? () => _handleExport() : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!,
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _generateReport,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _result == null
                  ? const Center(
                      child: Text('Tap Generate to view the report.'),
                    )
                  : DefaultTabController(
                      length: 2,
                      child: Scaffold(
                        body: NestedScrollView(
                          headerSliverBuilder:
                              (BuildContext context, bool innerBoxIsScrolled) {
                            return [
                              SliverAppBar(
                                pinned: true,
                                title: Text(_result!.definition.title),
                                bottom: const TabBar(
                                  tabs: [
                                    Tab(text: 'Summary'),
                                    Tab(text: 'Details'),
                                  ],
                                ),
                              ),
                            ];
                          },
                          body: TabBarView(
                            children: [
                              _buildSummarySection(context),
                              _buildDetailsSection(context),
                            ],
                          ),
                        ),
                        bottomSheet: _showExport
                            ? const LinearProgressIndicator()
                            : _result!.details?.isNotEmpty == true
                                ? Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.end,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: _handleExport,
                                        icon: const Icon(Icons.download),
                                        label: const Text('Export Excel'),
                                      ),
                                    ],
                                  )
                                : null,
                      ),
                    ),
    );
  }
}