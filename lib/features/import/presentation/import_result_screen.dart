import 'package:flutter/material.dart';

import '../application/import_service.dart';

/// Final step of the import flow: what was imported, what was skipped, and a
/// way to export a CSV report of everything that was not imported.
class ImportResultScreen extends StatelessWidget {
  const ImportResultScreen({
    super.key,
    required this.service,
    required this.onDone,
  });

  final ImportService service;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = service.result;
    if (result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final hasFailures = result.failures.isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 56,
                    color: hasFailures
                        ? theme.colorScheme.tertiary
                        : Colors.green,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Import finished',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasFailures
                        ? 'Most records were imported. See the report below for '
                              'the rows that were skipped.'
                        : 'Every row was imported successfully.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _ResultStat(
                        label: 'Students imported',
                        value: result.importedStudents,
                        color: Colors.green,
                      ),
                      _ResultStat(
                        label: 'New families',
                        value: result.importedFamilies,
                        color: Colors.teal,
                      ),
                      _ResultStat(
                        label: 'Duplicates skipped',
                        value: result.skippedDuplicates,
                        color: Colors.orange,
                      ),
                      _ResultStat(
                        label: 'Invalid skipped',
                        value: result.skippedInvalid,
                        color: Colors.grey,
                      ),
                      _ResultStat(
                        label: 'Custom fields created',
                        value: result.createdCustomFields.length,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                  if (result.createdCustomFields.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Custom fields: ${result.createdCustomFields.join(', ')}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                  if (hasFailures) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Skipped rows',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: result.failures.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final failure = result.failures[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                            ),
                            title: Text(failure.field),
                            subtitle: Text(failure.message),
                          );
                        },
                      ),
                    ),
                  ],
                  if (service.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      service.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (hasFailures) ...[
                        OutlinedButton.icon(
                          key: const Key('import_export_report'),
                          onPressed: service.busy ? null : service.exportReport,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Export report'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      FilledButton.icon(
                        key: const Key('import_done'),
                        onPressed: service.busy ? null : onDone,
                        icon: const Icon(Icons.done_rounded),
                        label: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
