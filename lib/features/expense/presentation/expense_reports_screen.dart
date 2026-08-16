import 'package:flutter/material.dart';

import '../domain/entities/expense_category.dart';
import '../domain/entities/expense_category_total.dart';
import '../domain/entities/expense_monthly_totals.dart';
import '../domain/services/expense_service.dart';
import '../../../shared/utils/formatters.dart';

/// Monthly expense reports with category breakdown and export.
class ExpenseReportsScreen extends StatefulWidget {
  const ExpenseReportsScreen({
    super.key,
    required this.expenseService,
  });

  final ExpenseService expenseService;

  @override
  State<ExpenseReportsScreen> createState() => _ExpenseReportsScreenState();
}

class _ExpenseReportsScreenState extends State<ExpenseReportsScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _isLoading = true;
  String? _error;
  ExpenseMonthlyTotals? _totals;
  List<ExpenseCategoryTotal> _categoryTotals = const [];

  @override
  void initState() {
    super.initState();
    _loadDistinctYears();
    _loadReport();
  }

  Future<void> _loadDistinctYears() async {
    final years = await widget.expenseService.distinctYears();
    if (!mounted) return;
    setState(() {
      if (years.isNotEmpty) {
        _selectedYear = years.first;
      }
    });
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    _error = null;
    try {
      final totals =
          await widget.expenseService.monthlyTotals(
            year: _selectedYear,
            month: _selectedMonth,
          );
      final categoryTotals =
          await widget.expenseService.categoryTotals(
            from: DateTime(_selectedYear, _selectedMonth, 1),
            to: DateTime(_selectedYear, _selectedMonth + 1, 0),
          );
      if (!mounted) return;
      setState(() {
        _totals = totals;
        _categoryTotals = categoryTotals;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load report: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_monthName(_selectedMonth)} $_selectedYear Expenses',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _loadReport,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMonthPicker(theme),
                      const SizedBox(height: 32),
                      _buildMonthlyTotal(theme, _totals!),
                      const SizedBox(height: 32),
                      _buildCategoryBreakdown(theme, _categoryTotals),
                      const SizedBox(height: 24),
                      _buildExportButton(theme),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMonthPicker(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('Month: ',
                style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<int>(
              value: _selectedMonth,
              items: List.generate(12, (index) {
                final month = index + 1;
                return DropdownMenuItem<int>(
                  value: month,
                  child: Text('${_monthName(month)} $_selectedYear'),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedMonth = value;
                  });
                  _loadReport();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTotal(ThemeData theme, ExpenseMonthlyTotals totals) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Monthly Total',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              Formatters.money(totals.totalAmount),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Records: ${totals.recordCount}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Period: ${totals.periodLabel}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown(ThemeData theme,
      List<ExpenseCategoryTotal> categoryTotals) {
    if (categoryTotals.isEmpty) {
      return const Center(
        child: Text('No category data available.'),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...categoryTotals.map((total) => _CategoryTotalRow(
                  key: Key('category_${total.category.dbValue}'),
                  category: total.category,
                  total: total.totalAmount,
                  count: total.recordCount,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ElevatedButton.icon(
          onPressed: _exportExpenses,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Export to Excel'),
        ),
      ),
    );
  }

  Future<void> _exportExpenses() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Export functionality will be available in Module 11. '
          'Uses existing Excel export service.',
        ),
      ),
    );
  }
}

class _CategoryTotalRow extends StatelessWidget {
  const _CategoryTotalRow({
    super.key,
    required this.category,
    required this.total,
    required this.count,
  });

  final ExpenseCategory category;
  final double total;
  final int count;

  Color _getCategoryColor() {
    switch (category.dbValue) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getCategoryColor()
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              category.label,
              style: TextStyle(
                color: _getCategoryColor(),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const Spacer(),
          Text(
            Formatters.money(total),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count records',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}