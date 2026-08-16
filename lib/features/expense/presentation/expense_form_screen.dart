import 'package:flutter/material.dart';

import '../domain/entities/expense.dart';
import '../domain/entities/expense_category.dart';
import '../domain/services/expense_service.dart';
import '../../../shared/utils/formatters.dart';

/// Create / edit an expense record.
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({
    super.key,
    required this.expenseService,
    this.existing,
  });

  final ExpenseService expenseService;
  final Expense? existing;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _reference;
  late final TextEditingController _amount;
  late ExpenseCategory _category;
  bool _isEditing = false;
  bool _submitting = false;
  String? _expenseId;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existing != null;
    final existing = widget.existing;
    _category = existing != null && existing.category.isNotEmpty
        ? ExpenseCategory.fromDb(existing.category)
        : ExpenseCategory.other;
    _description = TextEditingController(text: existing?.description ?? '');
    _reference = TextEditingController(text: existing?.reference ?? '');
    _amount = TextEditingController(
      text: existing == null || existing.amount == 0
          ? ''
          : Formatters.money(existing.amount, symbol: 'Rs').replaceAll('Rs ', ''),
    );
    if (existing != null) {
      _expenseId = existing.expenseId;
    } else {
      widget.expenseService.nextExpenseId().then((id) {
        if (mounted) setState(() => _expenseId = id);
      });
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _reference.dispose();
    _amount.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _validateAmount(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Amount is required.';
    final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
    if (parsed == null) return 'Enter a valid amount.';
    if (parsed <= 0) return 'Amount must be greater than zero.';
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isEditing) ...[
                        Text(
                          'Expense ID: $_expenseId',
                          style: theme.textTheme.labelMedium,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        key: const Key('expense_description'),
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(),
                        ),
                        controller: _description,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            _validateRequired(value, 'Please enter a description.'),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ExpenseCategory>(
                        decoration: const InputDecoration(
                          labelText: 'Category *',
                          border: OutlineInputBorder(),
                        ),
                        value: _category,
                        items: ExpenseCategory.values
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.label),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _category = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('expense_amount'),
                              decoration: const InputDecoration(
                                labelText: 'Amount *',
                                border: OutlineInputBorder(),
                                hintText: 'e.g. 5000',
                              ),
                              controller: _amount,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              textInputAction: TextInputAction.next,
                              validator: _validateAmount,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Reference',
                                border: OutlineInputBorder(),
                                hintText: 'Optional bill/reference number',
                              ),
                              controller: _reference,
                              textInputAction: TextInputAction.done,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Date *'),
                        trailing: const Text(
                          'Set date in form',
                          style: TextStyle(color: Colors.grey),
                        ),
        onTap: _pickDate,
      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _submitting
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                key: const Key('expense_submit'),
                                onPressed: _submit,
                                child: Text(_isEditing ? 'Save changes' : 'Add Expense'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final amount = double.tryParse(
        _amount.text.trim().replaceAll(',', '.'),
      ) ?? 0;

      final created = await widget.expenseService.createExpense(
        date: DateTime.now(),
        category: _category,
        amount: amount,
        description: _description.text.trim(),
        reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
      );
      if (!mounted) return;
      if (_isEditing) {
        Navigator.of(context).pop(created);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense created. Expense ID: EXP-000001'),
          ),
        );
        Navigator.of(context).pop(created);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('ArgumentError: ', '')),
        ),
      );
    }
  }
}