import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../domain/entities/salary_monthly_totals.dart';
import '../domain/entities/salary_period.dart';
import '../domain/entities/salary_record_list_item.dart';
import '../domain/entities/salary_status.dart';
import '../domain/services/salary_service.dart';
import 'salary_form_screen.dart';
import 'salary_record_detail_screen.dart';
import 'widgets/salary_period_picker.dart';
import 'widgets/salary_status_chip.dart';

/// Searches salary records by employee, month, year and status, and shows the
/// monthly salary totals.
class SalaryRecordsScreen extends StatefulWidget {
  const SalaryRecordsScreen({super.key, required this.salaryService});

  final SalaryService salaryService;

  @override
  State<SalaryRecordsScreen> createState() => _SalaryRecordsScreenState();
}

class _SalaryRecordsScreenState extends State<SalaryRecordsScreen> {
  List<int> _years = const [];
  List<SalaryRecordListItem> _results = const [];
  SalaryMonthlyTotals? _totals;
  bool _loading = true;
  String? _error;

  String _query = '';
  SalaryStatus? _status;
  SalaryPeriod? _period;
  int? _year;

  @override
  void initState() {
    super.initState();
    _loadYears();
    _loadTotals();
    _search();
  }

  Future<void> _loadYears() async {
    try {
      final years = await widget.salaryService.distinctYears();
      if (!mounted) return;
      setState(() => _years = years);
    } catch (_) {
      // Years are a convenience filter; a failure here is non-fatal.
    }
  }

  Future<void> _loadTotals() async {
    final period = _period ?? SalaryPeriod.current();
    try {
      final totals = await widget.salaryService.monthlyTotals(
        year: period.year,
        month: period.month,
      );
      if (!mounted) return;
      setState(() => _totals = totals);
    } catch (_) {
      if (!mounted) return;
      setState(() => _totals = null);
    }
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.salaryService.repository.searchSalaries(
        query: _query,
        period: _period,
        status: _status,
        year: _year,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Salary records could not be loaded.';
        _loading = false;
      });
    }
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalaryFormScreen(salaryService: widget.salaryService),
      ),
    );
    await _loadYears();
    await _loadTotals();
    await _search();
  }

  Future<void> _openDetails(SalaryRecordListItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalaryRecordDetailScreen(
          salaryService: widget.salaryService,
          recordId: item.record.id,
        ),
      ),
    );
    await _loadTotals();
    await _search();
  }

  Future<void> _pickPeriod() async {
    var selected = _period ?? SalaryPeriod.current();
    final picked = await showDialog<SalaryPeriod>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter by month'),
            content: SalaryPeriodPicker(
              period: selected,
              onChanged: (value) => setDialogState(() => selected = value),
            ),
            actions: [
              TextButton(
                key: const Key('salary_filter_clear_month'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                key: const Key('salary_filter_apply_month'),
                onPressed: () => Navigator.of(context).pop(selected),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
    if (picked == null) return;
    setState(() => _period = picked);
    await _loadTotals();
    await _search();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Salary Records')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('salary_record_fab'),
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Record Salary'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              key: const Key('salary_records_search'),
              onChanged: (value) {
                _query = value;
                _search();
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by employee ID or name…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusFilter(theme),
                _buildYearFilter(theme),
                OutlinedButton.icon(
                  key: const Key('salary_filter_month'),
                  onPressed: _pickPeriod,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(_period?.label ?? 'All months'),
                ),
                if (_status != null || _period != null || _year != null)
                  TextButton.icon(
                    key: const Key('salary_filter_clear'),
                    onPressed: () {
                      setState(() {
                        _status = null;
                        _period = null;
                        _year = null;
                      });
                      _loadTotals();
                      _search();
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Clear filters'),
                  ),
              ],
            ),
          ),
          _buildTotalsCard(theme),
          const Divider(height: 1),
          Expanded(child: _buildResults(theme)),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(ThemeData theme) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<SalaryStatus?>(
        key: const Key('salary_filter_status'),
        value: _status,
        hint: const Text('All statuses'),
        items: [
          const DropdownMenuItem<SalaryStatus?>(
            value: null,
            child: Text('All statuses'),
          ),
          for (final status in SalaryStatus.values)
            DropdownMenuItem<SalaryStatus?>(
              value: status,
              child: Text(status.label),
            ),
        ],
        onChanged: (value) {
          setState(() => _status = value);
          _search();
        },
      ),
    );
  }

  Widget _buildYearFilter(ThemeData theme) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        key: const Key('salary_filter_year'),
        value: _year,
        hint: const Text('All years'),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('All years'),
          ),
          for (final year in _years)
            DropdownMenuItem<int?>(value: year, child: Text('$year')),
        ],
        onChanged: (value) {
          setState(() => _year = value);
          _search();
        },
      ),
    );
  }

  Widget _buildTotalsCard(ThemeData theme) {
    final totals = _totals;
    if (totals == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${totals.period.label} totals'
                '${totals.recordCount == 0 ? '' : ' · ${totals.recordCount} records'}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 20,
                runSpacing: 4,
                children: [
                  _totalItem(theme, 'Net payable', totals.netPayable),
                  _totalItem(theme, 'Paid', totals.totalPaid,
                      color: Colors.green.shade700),
                  _totalItem(theme, 'Pending', totals.totalPending,
                      color: Colors.orange.shade800),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalItem(
    ThemeData theme,
    String label,
    double value, {
    Color? color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        Text(
          Formatters.money(value),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildResults(ThemeData theme) {
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.payments_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No salary records match these filters.',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _results[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            key: Key('salary_record_${item.record.id}'),
            onTap: () => _openDetails(item),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.employeeName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SalaryStatusChip(status: item.record.status),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  item.record.period.label,
                  item.employeeCode,
                  item.record.salaryRecordId,
                ].join(' · '),
              ),
            ),
            trailing: Text(
              Formatters.money(item.record.netAmount),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}
