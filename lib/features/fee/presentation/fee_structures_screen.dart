import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/utils/formatters.dart';
import '../application/fee_service.dart';
import '../domain/entities/fee_structure.dart';

/// CRUD for the monthly fee rules (one per class plus a default rule).
class FeeStructuresScreen extends StatefulWidget {
  const FeeStructuresScreen({super.key, required this.feeService});

  final FeeService feeService;

  @override
  State<FeeStructuresScreen> createState() => _FeeStructuresScreenState();
}

class _FeeStructuresScreenState extends State<FeeStructuresScreen> {
  List<FeeStructure> _structures = const [];
  List<String> _classes = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final classes = await widget.feeService.repository.distinctClasses();
      final structures = await widget.feeService.repository
          .listFeeStructures();
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _structures = structures;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Fee rules could not be loaded.';
        _loading = false;
      });
    }
  }

  Future<void> _openForm({FeeStructure? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _StructureFormDialog(
        feeService: widget.feeService,
        classes: _classes,
        existing: existing,
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _toggle(FeeStructure structure, bool isActive) async {
    setState(() {
      _structures = [
        for (final s in _structures)
          if (s.id == structure.id) _structureWithActive(s, isActive) else s,
      ];
    });
    try {
      await widget.feeService.repository
          .setFeeStructureActive(structure.id, isActive);
    } catch (_) {
      _showSnack('Could not update the rule.');
      await _load();
    }
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
      appBar: AppBar(title: const Text('Fee Structures')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('structure_add_fab'),
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Rule'),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
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
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_structures.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.rule_rounded,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'No fee rules yet.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Add at least a default rule before generating monthly fees.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: _structures.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final structure = _structures[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              structure.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (structure.isDefault) ...[
                            const SizedBox(width: 8),
                            _pill(theme, 'Default'),
                          ],
                          if (!structure.isActive) ...[
                            const SizedBox(width: 8),
                            _pill(theme, 'Inactive'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        structure.isDefault
                            ? 'Applies when a class has no rule'
                            : 'Class ${structure.className}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${Formatters.money(structure.monthlyAmount)} / month'
                        '${structure.discountAmount > 0
                            ? ' · discount ${Formatters.money(structure.discountAmount)}'
                            : ''}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (structure.description != null)
                        Text(
                          structure.description!,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      key: Key('structure_edit_${structure.id}'),
                      tooltip: 'Edit rule',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openForm(existing: structure),
                    ),
                    Switch(
                      key: Key('structure_active_${structure.id}'),
                      value: structure.isActive,
                      onChanged: (value) => _toggle(structure, value),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pill(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _StructureFormDialog extends StatefulWidget {
  const _StructureFormDialog({
    required this.feeService,
    required this.classes,
    this.existing,
  });

  final FeeService feeService;
  final List<String> classes;
  final FeeStructure? existing;

  @override
  State<_StructureFormDialog> createState() => _StructureFormDialogState();
}

class _StructureFormDialogState extends State<_StructureFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _discount;
  late final TextEditingController _description;
  String? _className;
  bool _submitting = false;
  String? _error;

  List<String> get _classOptions {
    final options = [...widget.classes];
    final current = widget.existing?.className;
    if (current != null && !options.contains(current)) {
      options.add(current);
    }
    return options;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _amount = TextEditingController(
      text: existing?.monthlyAmount.toStringAsFixed(2) ?? '',
    );
    _discount = TextEditingController(
      text: existing?.discountAmount.toStringAsFixed(2) ?? '0',
    );
    _description = TextEditingController(text: existing?.description ?? '');
    _className = existing?.className;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _discount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    final discount = double.tryParse(_discount.text.trim());
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Rule name is required.');
      return;
    }
    if (amount == null || discount == null || amount < 0 || discount < 0) {
      setState(() => _error = 'Enter valid, non-negative amounts.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final existing = widget.existing;
      if (existing == null) {
        await widget.feeService.repository.createFeeStructure(
          name: _name.text,
          className: _className,
          monthlyAmount: amount,
          discountAmount: discount,
          description: _description.text,
        );
      } else {
        await widget.feeService.repository.updateFeeStructure(
          id: existing.id,
          name: _name.text,
          className: _className,
          monthlyAmount: amount,
          discountAmount: discount,
          description: _description.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message?.toString();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'The rule could not be saved.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Fee Rule' : 'Edit Fee Rule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('structure_name_field'),
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Rule name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const Key('structure_class_field'),
              initialValue: _className,
              decoration: const InputDecoration(
                labelText: 'Applies to class',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Default rule (no class)'),
                ),
                for (final c in _classOptions)
                  DropdownMenuItem<String?>(value: c, child: Text(c)),
              ],
              onChanged: (value) => setState(() => _className = value),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('structure_amount_field'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monthly amount',
                prefixText: '${AppConfig.currencySymbol} ',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('structure_discount_field'),
              controller: _discount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monthly discount',
                prefixText: '${AppConfig.currencySymbol} ',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('structure_description_field'),
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('structure_save_button'),
          onPressed: _submitting ? null : _save,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// Copies [structure] with the active flag replaced.
FeeStructure _structureWithActive(FeeStructure structure, bool isActive) {
  return FeeStructure(
    id: structure.id,
    structureId: structure.structureId,
    name: structure.name,
    className: structure.className,
    monthlyAmount: structure.monthlyAmount,
    discountAmount: structure.discountAmount,
    description: structure.description,
    isActive: isActive,
  );
}
