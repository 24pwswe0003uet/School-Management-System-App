import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../application/salary_calculator.dart';
import '../domain/entities/salary_employee_pick.dart';
import '../domain/entities/salary_period.dart';
import '../domain/entities/salary_record.dart';
import '../domain/entities/salary_status.dart';
import '../domain/repositories/salary_period_exists_exception.dart';
import '../domain/services/salary_service.dart';
import 'widgets/salary_period_picker.dart';

/// Create / edit a monthly salary record.
///
/// The net amount is never entered by hand — it is computed live from the
/// components by [SalaryCalculator] and previewed below the fields. Creating a
/// second record for the same employee and month is prevented: the form
/// switches to editing the existing record instead of overwriting it silently.
class SalaryFormScreen extends StatefulWidget {
  const SalaryFormScreen({
    super.key,
    required this.salaryService,
    this.employee,
    this.existing,
    this.existingEmployee,
  });

  final SalaryService salaryService;

  /// Pre-selected employee (e.g. from the staff profile "Record Salary").
  final SalaryEmployeePick? employee;

  /// Existing record to edit. [existingEmployee] provides its display details.
  final SalaryRecord? existing;
  final SalaryEmployeePick? existingEmployee;

  @override
  State<SalaryFormScreen> createState() => _SalaryFormScreenState();
}

class _SalaryFormScreenState extends State<SalaryFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _employeeText;
  late final TextEditingController _periodText;
  late final TextEditingController _base;
  late final TextEditingController _advance;
  late final TextEditingController _deduction;
  late final TextEditingController _adjustment;
  late final TextEditingController _paymentDate;
  late final TextEditingController _notes;

  SalaryEmployeePick? _employee;
  SalaryPeriod _period = SalaryPeriod.current();
  SalaryStatus _status = SalaryStatus.pending;
  DateTime? _paymentDateValue;
  SalaryRecord? _existing;
  bool _submitting = false;

  bool get _isEdit => _existing != null;

  @override
  void initState() {
    super.initState();
    _existing = widget.existing;
    if (widget.employee != null) {
      _employee = widget.employee;
      _employeeText = TextEditingController(
        text: _employeeLabel(widget.employee!),
      );
      _base = TextEditingController(
        text: widget.employee!.basicSalary > 0
            ? _salaryText(widget.employee!.basicSalary)
            : '',
      );
    } else {
      _employeeText = TextEditingController();
      _base = TextEditingController();
    }
    if (_existing != null) {
      _period = _existing!.period;
      _periodText = TextEditingController(text: _period.label);
    } else {
      _periodText = TextEditingController(text: _period.label);
    }
    _advance = TextEditingController();
    _deduction = TextEditingController();
    _adjustment = TextEditingController();
    _paymentDate = TextEditingController();
    _notes = TextEditingController();

    if (_existing != null) {
      final record = _existing!;
      _employee = widget.existingEmployee;
      if (_employee != null) {
        _employeeText.text = _employeeLabel(_employee!);
      } else {
        _employeeText.text = 'Employee #${record.employeeId}';
      }
      _base.text = _salaryText(record.baseSalary);
      _advance.text = _salaryText(record.advance);
      _deduction.text = _salaryText(record.deduction);
      _adjustment.text = _salaryText(record.otherAdjustment);
      _status = record.status;
      _paymentDateValue = record.paymentDate;
      _paymentDate.text = record.paymentDate == null
          ? ''
          : Formatters.date(record.paymentDate!);
      _notes.text = record.notes ?? '';
    }

    for (final controller in [
      _base,
      _advance,
      _deduction,
      _adjustment,
    ]) {
      controller.addListener(_onAmountsChanged);
    }
  }

  void _onAmountsChanged() => setState(() {});

  @override
  void dispose() {
    _employeeText.dispose();
    _periodText.dispose();
    _base.dispose();
    _advance.dispose();
    _deduction.dispose();
    _adjustment.dispose();
    _paymentDate.dispose();
    _notes.dispose();
    super.dispose();
  }

  static String _salaryText(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  static String _employeeLabel(SalaryEmployeePick pick) {
    return '${pick.employeeCode} · ${pick.name}';
  }

  static double _parseAmount(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  String? _validateAmount(String? value, String label) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return 'Enter a valid amount.';
    if (parsed < 0) return '$label cannot be negative.';
    return null;
  }

  String? _validateAdjustment(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (double.tryParse(trimmed) == null) return 'Enter a valid amount.';
    return null;
  }

  String? _validatePaymentDate(String? value) {
    if (_status == SalaryStatus.paid && _paymentDateValue == null) {
      return 'Payment date is required when the salary is paid.';
    }
    return null;
  }

  Future<void> _pickEmployee() async {
    final picked = await showDialog<SalaryEmployeePick>(
      context: context,
      builder: (_) => _EmployeeSearchDialog(
        salaryService: widget.salaryService,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _employee = picked;
      _employeeText.text = _employeeLabel(picked);
      if (_base.text.trim().isEmpty && picked.basicSalary > 0) {
        _base.text = _salaryText(picked.basicSalary);
      }
    });
  }

  Future<void> _pickPeriod() async {
    var selected = _period;
    final picked = await showDialog<SalaryPeriod>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Select salary month'),
            content: SalaryPeriodPicker(
              period: selected,
              onChanged: (value) => setDialogState(() => selected = value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('salary_period_apply'),
                onPressed: () => Navigator.of(context).pop(selected),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _period = picked;
      _periodText.text = picked.label;
    });
  }

  Future<void> _pickPaymentDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDateValue ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _paymentDateValue = picked;
      _paymentDate.text = Formatters.date(picked);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && _employee == null) {
      _showSnack('Select an employee first.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final base = _parseAmount(_base);
      final advance = _parseAmount(_advance);
      final deduction = _parseAmount(_deduction);
      final adjustment = _parseAmount(_adjustment);
      final paymentDate = _status == SalaryStatus.paid
          ? _paymentDateValue
          : null;
      final notes = _notes.text;

      if (_isEdit) {
        await widget.salaryService.updateSalary(
          id: _existing!.id,
          baseSalary: base,
          advance: advance,
          deduction: deduction,
          otherAdjustment: adjustment,
          status: _status,
          paymentDate: paymentDate,
          notes: notes,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      final existing = await widget.salaryService.getSalaryForPeriod(
        _employee!.id,
        _period,
      );
      if (existing != null) {
        setState(() => _submitting = false);
        final edit = await _showExistsDialog(existing);
        if (edit == true && mounted) {
          setState(() {
            _existing = existing;
            _applyRecord(existing);
          });
        }
        return;
      }

      await widget.salaryService.createSalary(
        employeeId: _employee!.id,
        period: _period,
        baseSalary: base,
        advance: advance,
        deduction: deduction,
        otherAdjustment: adjustment,
        status: _status,
        paymentDate: paymentDate,
        notes: notes,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on SalaryPeriodExistsException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnack(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnack('Could not save the salary record. Please try again.');
    }
  }

  /// Loads an existing record's values into the form (used when a duplicate
  /// create is detected). The selected employee/period are the ones the record
  /// belongs to, so the read-only identity stays consistent.
  void _applyRecord(SalaryRecord record) {
    _period = record.period;
    _periodText.text = record.period.label;
    _base.text = _salaryText(record.baseSalary);
    _advance.text = _salaryText(record.advance);
    _deduction.text = _salaryText(record.deduction);
    _adjustment.text = _salaryText(record.otherAdjustment);
    _status = record.status;
    _paymentDateValue = record.paymentDate;
    _paymentDate.text = record.paymentDate == null
        ? ''
        : Formatters.date(record.paymentDate!);
    _notes.text = record.notes ?? '';
  }

  Future<bool?> _showExistsDialog(SalaryRecord existing) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salary already exists'),
        content: Text(
          '${_employee!.employeeCode} already has a record for '
          '${existing.period.label} (${existing.salaryRecordId}). Edit that '
          'record instead of creating a duplicate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('salary_exists_edit'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Edit existing'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Salary' : 'Record Salary')),
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
                      TextFormField(
                        key: const Key('salary_employee'),
                        controller: _employeeText,
                        readOnly: true,
                        onTap: _isEdit ? null : _pickEmployee,
                        decoration: InputDecoration(
                          labelText: _isEdit ? 'Employee' : 'Employee *',
                          hintText: _isEdit ? null : 'Search staff by ID or name',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: const OutlineInputBorder(),
                          suffixIcon: _isEdit
                              ? null
                              : const Icon(Icons.search),
                        ),
                        validator: (value) {
                          if (_isEdit) return null;
                          if (value == null || value.trim().isEmpty) {
                            return 'Please select an employee.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('salary_period'),
                        controller: _periodText,
                        readOnly: true,
                        onTap: _isEdit ? null : _pickPeriod,
                        decoration: const InputDecoration(
                          labelText: 'Salary month *',
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please select the salary month.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('salary_base'),
                        controller: _base,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Base salary *',
                          hintText: 'e.g. 30000',
                          prefixIcon: Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => _validateAmount(
                          value,
                          'Base salary',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('salary_advance'),
                              controller: _advance,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Advance',
                                hintText: '0',
                                prefixIcon: Icon(Icons.currency_rupee),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  _validateAmount(value, 'Advance'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              key: const Key('salary_deduction'),
                              controller: _deduction,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Deduction',
                                hintText: '0',
                                prefixIcon: Icon(Icons.currency_rupee),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  _validateAmount(value, 'Deduction'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('salary_adjustment'),
                        controller: _adjustment,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Other adjustment',
                          hintText: 'Optional — use + or -',
                          prefixIcon: Icon(Icons.tune_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateAdjustment,
                      ),
                      const SizedBox(height: 16),
                      _buildNetPreview(theme),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<SalaryStatus>(
                        key: const Key('salary_status'),
                        initialValue: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status *',
                          prefixIcon: Icon(Icons.flag_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final status in SalaryStatus.values)
                            DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _status = value);
                          }
                        },
                      ),
                      if (_status == SalaryStatus.paid) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('salary_payment_date'),
                          controller: _paymentDate,
                          readOnly: true,
                          onTap: _pickPaymentDate,
                          decoration: InputDecoration(
                            labelText: 'Payment date *',
                            prefixIcon: const Icon(
                              Icons.calendar_today_outlined,
                            ),
                            border: const OutlineInputBorder(),
                            suffixIcon: _paymentDateValue != null
                                ? IconButton(
                                    tooltip: 'Clear date',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => setState(() {
                                      _paymentDateValue = null;
                                      _paymentDate.text = '';
                                    }),
                                  )
                                : null,
                          ),
                          validator: _validatePaymentDate,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('salary_notes'),
                        controller: _notes,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          key: const Key('salary_save'),
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(_isEdit ? 'Save changes' : 'Save record'),
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

  Widget _buildNetPreview(ThemeData theme) {
    final base = _parseAmount(_base);
    final advance = _parseAmount(_advance);
    final deduction = _parseAmount(_deduction);
    final adjustment = _parseAmount(_adjustment);
    final clamped = SalaryCalculator.isClamped(
      base: base,
      advance: advance,
      deduction: deduction,
      otherAdjustment: adjustment,
    );
    final net = SalaryCalculator.netPayable(
      base: base,
      advance: advance,
      deduction: deduction,
      otherAdjustment: adjustment,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined, size: 18),
              const SizedBox(width: 8),
              Text(
                'Net payable',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                Formatters.money(net),
                key: const Key('salary_net_preview'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (clamped) ...[
            const SizedBox(height: 6),
            Text(
              'Adjustments exceed the base salary, so the net is clamped to '
              'Rs 0. Review the advance, deduction or adjustment.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-screen employee search used by the salary form's employee picker.
class _EmployeeSearchDialog extends StatefulWidget {
  const _EmployeeSearchDialog({required this.salaryService});

  final SalaryService salaryService;

  @override
  State<_EmployeeSearchDialog> createState() => _EmployeeSearchDialogState();
}

class _EmployeeSearchDialogState extends State<_EmployeeSearchDialog> {
  List<SalaryEmployeePick> _results = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final results = await widget.salaryService.searchEmployees(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (_) {
      if (!mounted) return;
      setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                key: const Key('salary_employee_search'),
                autofocus: true,
                onChanged: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search staff by ID or name…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _buildResults(theme),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No active staff found. Type to search.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final employee = _results[index];
        return ListTile(
          key: ValueKey('salary_pick_${employee.id}'),
          leading: const Icon(Icons.badge_outlined),
          title: Text(employee.name),
          subtitle: Text(
            [
              employee.employeeCode,
              if (employee.designation != null &&
                  employee.designation!.isNotEmpty)
                employee.designation!,
              if (employee.basicSalary > 0)
                Formatters.money(employee.basicSalary),
            ].join(' · '),
          ),
          onTap: () => Navigator.of(context).pop(employee),
        );
      },
    );
  }
}
