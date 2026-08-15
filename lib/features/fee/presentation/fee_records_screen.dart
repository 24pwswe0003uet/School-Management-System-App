import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../application/fee_service.dart';
import '../domain/entities/fee_period.dart';
import '../domain/entities/fee_record_list_item.dart';
import '../domain/entities/fee_status.dart';
import 'fee_record_detail_screen.dart';
import 'widgets/fee_status_chip.dart';
import 'widgets/month_period_picker.dart';

/// Searches monthly fee records by student, class, month and payment status.
class FeeRecordsScreen extends StatefulWidget {
  const FeeRecordsScreen({super.key, required this.feeService});

  final FeeService feeService;

  @override
  State<FeeRecordsScreen> createState() => _FeeRecordsScreenState();
}

class _FeeRecordsScreenState extends State<FeeRecordsScreen> {
  List<String> _classes = const [];
  List<FeeRecordListItem> _results = const [];
  bool _loading = true;
  String? _error;

  String _query = '';
  String? _className;
  FeeStatus? _status;
  FeePeriod? _period;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _search();
  }

  Future<void> _loadClasses() async {
    final classes = await widget.feeService.repository.distinctClasses();
    if (!mounted) return;
    setState(() => _classes = classes);
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.feeService.repository.searchFeeRecords(
        query: _query,
        period: _period,
        status: _status,
        className: _className,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Fee records could not be loaded.';
        _loading = false;
      });
    }
  }

  Future<void> _pickPeriod() async {
    var selected = _period ?? FeePeriod.current();
    final picked = await showDialog<FeePeriod>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter by month'),
            content: MonthPeriodPicker(
              period: selected,
              onChanged: (value) => setDialogState(() => selected = value),
            ),
            actions: [
              TextButton(
                key: const Key('fee_filter_clear_month'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                key: const Key('fee_filter_apply_month'),
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
    await _search();
  }

  Future<void> _openDetails(FeeRecordListItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FeeRecordDetailScreen(
          feeService: widget.feeService,
          recordId: item.record.id,
        ),
      ),
    );
    await _search();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Fee Records')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              key: const Key('fee_records_search'),
              onChanged: (value) {
                _query = value;
                _search();
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by student ID, name or family…',
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
                _buildClassFilter(theme),
                _buildStatusFilter(theme),
                OutlinedButton.icon(
                  key: const Key('fee_filter_month'),
                  onPressed: _pickPeriod,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(_period?.label ?? 'All months'),
                ),
                if (_className != null ||
                    _status != null ||
                    _period != null)
                  TextButton.icon(
                    key: const Key('fee_filter_clear'),
                    onPressed: () {
                      setState(() {
                        _className = null;
                        _status = null;
                        _period = null;
                      });
                      _search();
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Clear filters'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildResults(theme)),
        ],
      ),
    );
  }

  Widget _buildClassFilter(ThemeData theme) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        key: const Key('fee_filter_class'),
        value: _className,
        hint: const Text('All classes'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('All classes')),
          for (final c in _classes)
            DropdownMenuItem<String?>(value: c, child: Text(c)),
        ],
        onChanged: (value) {
          setState(() => _className = value);
          _search();
        },
      ),
    );
  }

  Widget _buildStatusFilter(ThemeData theme) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<FeeStatus?>(
        key: const Key('fee_filter_status'),
        value: _status,
        hint: const Text('All statuses'),
        items: [
          const DropdownMenuItem<FeeStatus?>(
            value: null,
            child: Text('All statuses'),
          ),
          for (final status in FeeStatus.values)
            DropdownMenuItem<FeeStatus?>(
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

  Widget _buildResults(ThemeData theme) {
    if (_loading) {
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
              Icons.receipt_long_rounded,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No fee records match these filters.',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _results[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            key: Key('fee_record_${item.record.id}'),
            onTap: () => _openDetails(item),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                FeeStatusChip(status: item.record.status),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  item.record.period.label,
                  item.studentId,
                  if (item.className != null) 'Class ${item.className}',
                ].join(' · '),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.money(item.record.remainingAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'remaining',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
