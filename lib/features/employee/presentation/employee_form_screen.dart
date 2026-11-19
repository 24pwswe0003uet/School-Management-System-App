import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../salary/domain/services/salary_service.dart';
import '../domain/entities/employee.dart';
import '../domain/entities/employee_category.dart';
import '../domain/services/employee_service.dart';
import 'employee_details_screen.dart';

/// Create / edit an employee. On create the generated employee ID is shown
/// read-only, and possible duplicates are surfaced before saving.
class EmployeeFormScreen extends StatefulWidget {
  const EmployeeFormScreen({
    super.key,
    required this.employeeService,
    required this.salaryService,
    this.existing,
  });

  final EmployeeService employeeService;
  final SalaryService salaryService;
  final Employee? existing;

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

sealed class _DupDecision {
  const _DupDecision();
}

class _DupCreate extends _DupDecision {
  const _DupCreate();
}

class _DupInspect extends _DupDecision {
  const _DupInspect(this.employee);

  final Employee employee;
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _designation;
  late final TextEditingController _department;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _cnic;
  late final TextEditingController _joiningDate;
  late final TextEditingController _basicSalary;
  late final TextEditingController _notes;
  late EmployeeCategory _category;

  DateTime? _joiningDateValue;
  bool _submitting = false;
  String? _employeeId;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _designation = TextEditingController(text: existing?.designation ?? '');
    _category = existing?.category ?? EmployeeCategory.teacher;
    _department = TextEditingController(text: existing?.department ?? '');
    _phone = TextEditingController(text: existing?.phone ?? '');
    _address = TextEditingController(text: existing?.address ?? '');
    _cnic = TextEditingController(text: existing?.cnic ?? '');
    _joiningDateValue = existing?.joiningDate;
    _joiningDate = TextEditingController(
      text: _joiningDateValue == null
          ? ''
          : Formatters.date(_joiningDateValue!),
    );
    _basicSalary = TextEditingController(
      text: existing == null || existing.basicSalary == 0
          ? ''
          : _salaryText(existing.basicSalary),
    );
    _notes = TextEditingController(text: existing?.notes ?? '');
    if (existing != null) {
      _employeeId = existing.employeeId;
    } else {
      widget.employeeService.nextEmployeeId().then((id) {
        if (mounted) setState(() => _employeeId = id);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _designation.dispose();
    _department.dispose();
    _phone.dispose();
    _address.dispose();
    _cnic.dispose();
    _joiningDate.dispose();
    _basicSalary.dispose();
    _notes.dispose();
    super.dispose();
  }

  static String _salaryText(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  String? _validateRequired(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _validatePhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^[0-9+\- ]+$').hasMatch(trimmed)) {
      return 'Phone can only contain digits, spaces, + or -.';
    }
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  String? _validateCnic(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 13) {
      return 'CNIC must be exactly 13 digits.';
    }
    return null;
  }

  String? _validateSalary(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return 'Enter a valid amount.';
    if (parsed < 0) return 'Salary cannot be negative.';
    return null;
  }

  Future<void> _pickJoiningDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDateValue ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _joiningDateValue = picked;
      _joiningDate.text = Formatters.date(picked);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final service = widget.employeeService;
      final existing = widget.existing;
      final name = _name.text;
      final designation = _designation.text;
      final department = _department.text;
      final phone = _phone.text;
      final address = _address.text;
      final cnic = _cnic.text;
      final notes = _notes.text;
      final basicSalary = double.tryParse(_basicSalary.text.trim()) ?? 0;

      if (!_isEdit) {
        final duplicates = await service.findPossibleDuplicates(
          name: name,
          phone: phone,
          cnic: cnic,
        );
        if (duplicates.isNotEmpty) {
          final decision = await _showDuplicateDialog(duplicates);
          if (!mounted) return;
          if (decision == null) {
            setState(() => _submitting = false);
            return;
          }
          if (decision is _DupInspect) {
            setState(() => _submitting = false);
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EmployeeDetailsScreen(
                  employeeService: service,
                  salaryService: widget.salaryService,
                  employeeId: decision.employee.id,
                ),
              ),
            );
            return;
          }
        }
        final created = await service.createEmployee(
          name: name,
          designation: designation,
          category: _category,
          department: department,
          phone: phone,
          address: address,
          cnic: cnic,
          joiningDate: _joiningDateValue,
          basicSalary: basicSalary,
          notes: notes,
        );
        if (!mounted) return;
        Navigator.of(context).pop(created);
      } else {
        final updated = await service.updateEmployee(
          id: existing!.id,
          name: name,
          designation: designation,
          category: _category,
          department: department,
          phone: phone,
          address: address,
          cnic: cnic,
          joiningDate: _joiningDateValue,
          basicSalary: basicSalary,
          notes: notes,
        );
        if (!mounted) return;
        Navigator.of(context).pop(updated);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not save the employee. Please try again.'),
          ),
        );
    }
  }

  Future<_DupDecision?> _showDuplicateDialog(List<Employee> duplicates) {
    return showDialog<_DupDecision>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Possible existing staff'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Similar staff members were found. Review them before saving '
                  'to avoid duplicate records.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    itemCount: duplicates.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final employee = duplicates[index];
                      return ListTile(
                        key: ValueKey('dup_${employee.employeeId}'),
                        dense: true,
                        leading: const Icon(Icons.badge_outlined),
                        title: Text(employee.name),
                        subtitle: Text(
                          [
                            employee.employeeId,
                            employee.category.label,
                            if (employee.phone != null &&
                                employee.phone!.isNotEmpty)
                              employee.phone!,
                          ].join(' · '),
                        ),
                        trailing: const Text('View'),
                        onTap: () =>
                            Navigator.of(context).pop(_DupInspect(employee)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('dup_cancel'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('dup_create_anyway'),
              onPressed: () => Navigator.of(context).pop(const _DupCreate()),
              child: const Text('Create anyway'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Staff' : 'Add Staff')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_employeeId != null) ...[
                        Text('Employee ID', style: theme.textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Text(
                          _employeeId!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      TextFormField(
                        key: const Key('employee_name'),
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Full name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            _validateRequired(value, 'Please enter the name.'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('employee_designation'),
                              controller: _designation,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Designation *',
                                hintText: 'e.g. Mathematics Teacher',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) => _validateRequired(
                                value,
                                'Please enter the designation.',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<EmployeeCategory>(
                              key: const Key('employee_category'),
                              initialValue: _category,
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final c in EmployeeService.categories)
                                  DropdownMenuItem(
                                    value: c,
                                    child: Text(c.label),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _category = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('employee_department'),
                        controller: _department,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          hintText: 'Optional, e.g. Science',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('employee_phone'),
                              controller: _phone,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                hintText: '0300-1234567',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validatePhone,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              key: const Key('employee_joining_date'),
                              controller: _joiningDate,
                              readOnly: true,
                              onTap: _pickJoiningDate,
                              decoration: InputDecoration(
                                labelText: 'Joining date',
                                suffixIcon: _joiningDateValue != null
                                    ? IconButton(
                                        tooltip: 'Clear date',
                                        icon: const Icon(Icons.clear),
                                        onPressed: () => setState(() {
                                          _joiningDateValue = null;
                                          _joiningDate.text = '';
                                        }),
                                      )
                                    : const Icon(
                                        Icons.calendar_today_outlined,
                                      ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('employee_basic_salary'),
                              controller: _basicSalary,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Current basic salary',
                                hintText: 'Optional, e.g. 25000',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validateSalary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              key: const Key('employee_cnic'),
                              controller: _cnic,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'CNIC (optional)',
                                hintText: 'XXXXX-XXXXXXX-X',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validateCnic,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('employee_address'),
                        controller: _address,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('employee_notes'),
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
                        child: LoadingButton(
                          key: const Key('employee_save'),
                          label: _isEdit ? 'Save changes' : 'Add staff',
                          icon: _isEdit ? Icons.save : Icons.person_add_rounded,
                          isLoading: _submitting,
                          onPressed: _submit,
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
}
