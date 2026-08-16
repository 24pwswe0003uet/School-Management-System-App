import 'package:flutter/material.dart';

import '../domain/entities/expense_category.dart';
import '../domain/entities/expense_list_item.dart';
import '../domain/services/expense_service.dart';
import 'expense_details_screen.dart';
import '../../../shared/utils/formatters.dart';

/// Searches, filters and lists expense records.
class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({
    super.key,
    required this.expenseService,
  });

  final ExpenseService expenseService;

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  List<ExpenseListItem> _results = const [];
  bool _loading = true;
  String? _error;

  String _query = '';
  ExpenseCategory? _categoryFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int? _yearFilter;
  int? _monthFilter;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.expenseService.searchExpenses(
        query: _query,
        category: _categoryFilter,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        year: _yearFilter,
        month: _monthFilter,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Expenses could not be loaded.';
        _loading = false;
      });
    }
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    var selectedFrom = _dateFrom ?? now;
    var selectedTo = _dateTo ?? now;

    final picked = await showDialog<DateTimeRange?>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter by date range'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDatePicker(
                        context,
                        initialDate: selectedFrom,
                        onChanged: (picked) =>
                            setDialogState(() => selectedFrom = picked),
                        firstDate: DateTime(2020),
                        lastDate: now,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDatePicker(
                        context,
                        initialDate: selectedTo,
                        onChanged: (picked) =>
                            setDialogState(() => selectedTo = picked),
                        firstDate: DateTime(2020),
                        lastDate: now,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(
                    DateTimeRange(start: selectedFrom, end: selectedTo),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (picked == null) return;

    setState(() {
      _dateFrom = picked.start;
      _dateTo = picked.end;
    });
    await _search();
  }

  Widget _buildDatePicker(
      BuildContext context,
      {
      required DateTime initialDate,
      required Function(DateTime) onChanged,
      required DateTime firstDate,
      required DateTime lastDate,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          [
            ListTile(
              title: Text(
                '${initialDate.day} ${_monthName(initialDate.month)} ${initialDate.year}',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initialDate,
                  firstDate: firstDate,
                  lastDate: lastDate,
                );
                if (picked != null) onChanged(picked);
              },
            ),
          ],
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Future<void> _openDetails(ExpenseListItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExpenseDetailsScreen(
          expenseService: widget.expenseService,
          expense: item.expense,
        ),
      ),
    );
    await _search();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Expense List')),
      body: Column(
        children: [
          _buildSearchBar(theme),
          const Divider(height: 1),
          _buildFilters(theme),
          const Divider(height: 1),
          Expanded(child: _buildResults(theme)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        key: const Key('expense_list_search'),
        onChanged: (value) {
          _query = value;
          _search();
        },
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search by expense ID, description, category, reference…',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildCategoryFilter(theme),
          OutlinedButton.icon(
            key: const Key('expense_filter_date_range'),
            onPressed: _pickPeriod,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(
              _dateRangeLabel(),
              style: TextStyle(fontSize: 12),
            ),
          ),
          if (_categoryFilter != null || _dateFrom != null || _dateTo != null ||
              _yearFilter != null || _monthFilter != null)
            TextButton.icon(
              key: const Key('expense_filter_clear'),
              onPressed: () {
                setState(() {
                  _categoryFilter = null;
                  _dateFrom = null;
                  _dateTo = null;
                  _yearFilter = null;
                  _monthFilter = null;
                });
                _search();
              },
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Clear filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(ThemeData theme) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<ExpenseCategory?>(
        key: const Key('expense_filter_category'),
        value: _categoryFilter,
        hint: const Text('All categories'),
        items: [
          const DropdownMenuItem<ExpenseCategory?>(
            value: null,
            child: Text('All categories'),
          ),
          for (final c in ExpenseCategory.values)
            DropdownMenuItem<ExpenseCategory?>(
              value: c,
              child: Text(c.label),
            ),
        ],
        onChanged: (value) {
          setState(() {
            _categoryFilter = value;
          });
          _search();
        },
      ),
    );
  }

  String _dateRangeLabel() {
    if (_dateFrom != null && _dateTo != null) {
      final from = '${_dateFrom!.day} ${_monthName(_dateFrom!.month)} ${_dateFrom!.year}';
      final to = '${_dateTo!.day} ${_monthName(_dateTo!.month)} ${_dateTo!.year}';
      return '$from – $to';
    }
    if (_dateFrom != null) {
      return '${_dateFrom!.day} ${_monthName(_dateFrom!.month)} ${_dateFrom!.year}';
    }
    if (_dateTo != null) {
      return '${_dateTo!.day} ${_monthName(_dateTo!.month)} ${_dateTo!.year}';
    }
    return 'Date range';
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
              'No expenses match these filters.',
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
            key: Key('expense_${item.expense.id}'),
            onTap: () => _openDetails(item),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.expense.expenseId,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: _categoryChipColor(item.expense.category),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.expense.category.isEmpty
                        ? 'Other'
                        : item.expense.category,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${item.expense.date.day} ${_monthName(item.expense.date.month)} ${item.expense.date.year} \u2022 ${Formatters.money(item.expense.amount)} \u2022 '
                '${() {
                  final desc = item.expense.description;
                  if (desc == null || desc.isEmpty) return 'No description';
                  return desc.length > 30 ? desc.substring(0, 30) : desc;
                }()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.money(item.expense.amount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Rs',
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

  Color _categoryChipColor(String category) {
    switch (category) {
      case 'electricity':
        return Colors.yellow;
      case 'water':
        return Colors.blue;
      case 'stationery':
        return Colors.brown;
      case 'maintenance':
        return Colors.orange;
      case 'cleaning':
        return Colors.green;
      case 'furniture':
        return Colors.purple;
      case 'transport':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}