import 'package:flutter/material.dart';

import '../domain/entities/expense.dart';
import '../domain/services/expense_service.dart';
import '../presentation/expense_form_screen.dart';
import '../../../shared/utils/formatters.dart';

/// Displays expense details and provides edit/delete actions.
class ExpenseDetailsScreen extends StatefulWidget {
  const ExpenseDetailsScreen({
    super.key,
    required this.expenseService,
    required this.expense,
  });

  final ExpenseService expenseService;
  final Expense expense;

  @override
  State<ExpenseDetailsScreen> createState() => _ExpenseDetailsScreenState();
}

class _ExpenseDetailsScreenState extends State<ExpenseDetailsScreen> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;

    return Scaffold(
      appBar: AppBar(
        title: Text(expense.expenseId),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
              onPressed: () => _editExpense(context),
              tooltip: 'Edit',
            ),
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteExpense,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              Icons.receipt_long_rounded,
              'Expense ID',
              expense.expenseId,
            ),
            const Divider(height: 32),
            _buildInfoRow(
              Icons.calendar_today_rounded,
              'Date',
              '${expense.date.day} ${_monthName(expense.date.month)} ${expense.date.year}',
            ),
            _buildInfoRow(
              Icons.category_rounded,
              'Category',
              expense.category.isEmpty
                  ? 'Other'
                  : expense.category,
              _categoryColor(expense.category),
            ),
            _buildInfoRow(
              Icons.money_rounded,
              'Amount',
              Formatters.money(expense.amount),
            ),
            _buildInfoRow(
              Icons.description_rounded,
              'Description',
              expense.description ?? 'No description provided',
            ),
            if (expense.reference != null && expense.reference!.isNotEmpty) ...[
              const Divider(height: 32),
              _buildInfoRow(
                Icons.receipt_rounded,
                'Reference',
                expense.reference!,
              ),
            ],
            const Divider(height: 32),
            _buildInfoRow(
              Icons.remove_circle_rounded,
              'Created By',
              expense.createdBy ?? 'Unknown',
            ),
            _buildInfoRow(
              Icons.schedule_rounded,
              'Created At',
              '${expense.createdAt.day} ${_monthName(expense.createdAt.month)} ${expense.createdAt.year}',
            ),
            _buildInfoRow(
              Icons.date_range_rounded,
              'Updated At',
              '${expense.updatedAt.day} ${_monthName(expense.updatedAt.month)} ${expense.updatedAt.year}',
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      [Color? iconColor]) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 16),
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
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Color _categoryColor(String category) {
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

  void _editExpense(BuildContext context) async {
    setState(() => _isEditing = true);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(
          expenseService: widget.expenseService,
          existing: widget.expense,
        ),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense updated.')),
      );
    }
    if (mounted) setState(() => _isEditing = false);
  }

  void _deleteExpense() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text(
          'This is a financial record. Are you sure you want to delete it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    try {
      await widget.expenseService.deleteExpense(widget.expense.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete expense: $e')),
      );
    }
  }
}