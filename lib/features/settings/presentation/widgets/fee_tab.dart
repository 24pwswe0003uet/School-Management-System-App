import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../fee/application/fee_service.dart';
import '../../../fee/domain/entities/fee_structure.dart';
import '../../../fee/presentation/fee_structures_screen.dart';
import '../../domain/services/settings_service.dart';

/// Fee tab: a read-only overview of the fee rules and a link to the full
/// editor in the Fee module. Rules themselves are not edited here — the
/// settings module deliberately defers to the existing Fee module so there is
/// a single source of truth.
class FeeTab extends StatefulWidget {
  const FeeTab({
    super.key,
    required this.settingsService,
    required this.feeService,
  });

  final SettingsService settingsService;
  final FeeService feeService;

  @override
  State<FeeTab> createState() => _FeeTabState();
}

class _FeeTabState extends State<FeeTab> {
  late Future<List<FeeStructure>> _structures;

  @override
  void initState() {
    super.initState();
    _structures = widget.feeService.repository.listFeeStructures();
  }

  void _refresh() {
    setState(() {
      _structures = widget.feeService.repository.listFeeStructures();
    });
  }

  Future<void> _openEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FeeStructuresScreen(feeService: widget.feeService),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fee structures',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Monthly fee rules live in the Fee module. One rule can '
                  'apply to all classes, with per-class overrides and optional '
                  'discounts. Manage them here:',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const Key('settings_open_fee_structures'),
                    onPressed: _openEditor,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Manage fee structures'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<FeeStructure>>(
          future: _structures,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                'Could not load fee structures.',
                style: theme.textTheme.bodyMedium,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final structures = snapshot.data!;
            if (structures.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No fee structures yet. Create one to start generating '
                    'monthly fees.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              );
            }
            return Card(
              child: Column(
                children: [
                  for (final structure in structures)
                    ListTile(
                      title: Text(structure.name),
                      subtitle: Text(
                        structure.isDefault
                            ? 'Applies to all classes'
                            : 'Class ${structure.className}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${AppConfig.currencySymbol}${structure.monthlyAmount.toStringAsFixed(0)}/month',
                            style: theme.textTheme.titleSmall,
                          ),
                          if (structure.discountAmount > 0)
                            Text(
                              '${structure.discountAmount.toStringAsFixed(0)} discount',
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
