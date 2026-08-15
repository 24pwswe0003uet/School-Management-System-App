import 'package:flutter/material.dart';

import '../application/import_service.dart';
import '../domain/entities/column_mapping.dart';
import '../domain/entities/import_fields.dart';
import '../domain/entities/import_plan.dart';
import '../domain/entities/import_row.dart';
import 'import_result_screen.dart';

/// Module 6, step 1 of the import flow. Walks the operator through file →
/// sheet → column mapping → preview → run, using one shared [ImportService].
class ImportScreen extends StatefulWidget {
  const ImportScreen({
    super.key,
    required this.service,
    required this.onFinished,
  });

  final ImportService service;
  final VoidCallback onFinished;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Students')),
      body: ListenableBuilder(
        listenable: widget.service,
        builder: (context, _) {
          final service = widget.service;
          final stepContent = switch (service.step) {
            ImportStep.pickFile => _buildPickFile(service),
            ImportStep.pickSheet => _buildPickSheet(service),
            ImportStep.mapColumns => _buildMapColumns(service),
            ImportStep.preview => _buildPreview(service),
            ImportStep.result => ImportResultScreen(
              service: service,
              onDone: _finish,
            ),
          };
          return Column(
            children: [
              if (service.running) const LinearProgressIndicator(),
              if (service.busy && !service.running)
                const LinearProgressIndicator(),
              Expanded(child: stepContent),
            ],
          );
        },
      ),
    );
  }

  void _finish() {
    widget.onFinished();
    Navigator.of(context).pop();
  }

  Widget _buildPickFile(ImportService service) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.table_view_rounded,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Import students from Excel',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose an .xlsx or .xls workbook. Unknown columns are kept '
                  'as custom fields and nothing is written until you confirm.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                if (service.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: service.errorMessage!),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('import_pick_file'),
                  onPressed: service.busy ? null : service.pickFile,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Choose Excel file'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickSheet(ImportService service) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Workbook: ${service.fileName}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose which worksheet contains the student data.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        if (service.errorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: service.errorMessage!),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final name in service.sheetNames)
              FilledButton.tonalIcon(
                key: Key('import_sheet_$name'),
                onPressed: service.busy
                    ? null
                    : () => service.selectSheet(name),
                icon: const Icon(Icons.grid_on_rounded),
                label: Text(name),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMapColumns(ImportService service) {
    final theme = Theme.of(context);
    final columns = service.columns;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Check the column mapping',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Columns you have not mapped become custom fields. '
                '${columns.where((c) => c.isCustom).length} new custom field(s) '
                'will be created.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              if (service.errorMessage != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: service.errorMessage!),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                for (var i = 0; i < columns.length; i++)
                  _MappingRow(
                    key: Key('import_map_${columns[i].sourceHeader}'),
                    mapping: columns[i],
                    onChanged: (value) => service.setColumnMapping(
                      i,
                      _applyMapping(columns[i], value),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: service.busy
                    ? null
                    : () => service.goTo(ImportStep.pickSheet),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: service.busy ? null : service.buildPlan,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continue'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(ImportService service) {
    final plan = service.plan;
    if (service.running) return _buildProgress(service);
    if (plan == null) return const SizedBox.shrink();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to import',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SummaryChip(
                    label: 'Valid',
                    value: plan.validCount,
                    color: Colors.green,
                  ),
                  _SummaryChip(
                    label: 'Possible duplicates',
                    value: plan.possibleDuplicateCount,
                    color: Colors.orange,
                  ),
                  _SummaryChip(
                    label: 'Duplicates',
                    value: plan.duplicateCount,
                    color: Colors.red,
                  ),
                  _SummaryChip(
                    label: 'Invalid',
                    value: plan.invalidCount,
                    color: Colors.grey,
                  ),
                  _SummaryChip(
                    label: 'New families',
                    value: plan.familiesNeeded,
                    color: Colors.teal,
                  ),
                ],
              ),
              if (service.errorMessage != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: service.errorMessage!),
              ],
              if (plan.hasIssues) ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  key: const Key('import_include_possible_duplicates'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Include possible duplicates'),
                  subtitle: const Text(
                    'Students that look similar to existing records will be '
                    'imported anyway.',
                  ),
                  value: service.includePossibleDuplicates,
                  onChanged: (value) =>
                      service.setIncludePossibleDuplicates(value ?? false),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _PreviewTable(plan: plan),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: service.running
                    ? null
                    : () => service.goTo(ImportStep.mapColumns),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                key: const Key('import_confirm'),
                onPressed: service.running
                    ? null
                    : () => _confirmImport(service),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Import'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmImport(ImportService service) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Back up first?'),
        content: const Text(
          'Importing writes a large number of records at once. It is strongly '
          'recommended to keep a database backup before you continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue Import'),
          ),
        ],
      ),
    );
    if (proceed == true) {
      await service.startImport();
    }
  }

  Widget _buildProgress(ImportService service) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Importing…',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${service.processed} of ${service.total} rows',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static ColumnMapping _applyMapping(ColumnMapping current, String value) {
    if (value == 'ignore') return current.asIgnored();
    if (value.startsWith('core:')) {
      final field = ImportCoreField.values.firstWhere(
        (f) => f.name == value.substring(5),
      );
      return current.asCore(field, ColumnMatchStatus.autoMatched);
    }
    final entityType = value.startsWith('custom:family') ? 'family' : 'student';
    final fieldName =
        current.customFieldName ??
        current.normalizedHeader.replaceAll(RegExp(r'\s+'), '_');
    return current.asCustom(
      fieldName,
      current.customDisplayName ?? current.sourceHeader,
      entityType: entityType,
      dataType: current.customDataType,
      match: ColumnMatchStatus.autoMatched,
    );
  }
}

class _MappingRow extends StatelessWidget {
  const _MappingRow({
    super.key,
    required this.mapping,
    required this.onChanged,
  });

  final ColumnMapping mapping;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = <String, String>{
      'ignore': 'Ignore column',
      for (final field in ImportCoreField.values)
        'core:${field.name}': field.displayName,
      'custom:student': 'Custom field (student)',
      'custom:family': 'Custom field (family)',
    };
    final current = switch (mapping.kind) {
      ColumnTargetKind.ignored => 'ignore',
      ColumnTargetKind.core => 'core:${mapping.coreField!.name}',
      ColumnTargetKind.custom =>
        mapping.customEntityType == 'family'
            ? 'custom:family'
            : 'custom:student',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mapping.sourceHeader,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Column ${mapping.index + 1}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                key: Key('import_map_${mapping.index}_dropdown'),
                initialValue: current,
                isExpanded: true,
                items: [
                  for (final entry in options.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onChanged(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.plan});

  final ImportPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = plan.rows;
    return Table(
      border: TableBorder.all(
        color: theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      columnWidths: const {
        0: FixedColumnWidth(64),
        1: FlexColumnWidth(2),
        2: FixedColumnWidth(150),
        3: FlexColumnWidth(3),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          children: const [
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Row', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Student',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Result',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('${row.index + 2}'),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(row.studentName ?? '—'),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: _VerdictChip(verdict: row.verdict),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_details(row)),
              ),
            ],
          ),
      ],
    );
  }

  static String _details(ImportRow row) {
    if (row.errors.isNotEmpty) {
      return row.errors.map((e) => '${e.field}: ${e.message}').join('; ');
    }
    return row.verdictMessage ?? '';
  }
}

class _VerdictChip extends StatelessWidget {
  const _VerdictChip({required this.verdict});

  final ImportRowVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (verdict) {
      ImportRowVerdict.valid => ('Valid', Colors.green),
      ImportRowVerdict.possibleDuplicate => ('Possible', Colors.orange),
      ImportRowVerdict.duplicate => ('Duplicate', Colors.red),
      ImportRowVerdict.invalid => ('Invalid', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
