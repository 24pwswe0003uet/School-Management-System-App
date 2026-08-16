import 'package:flutter/material.dart';

import '../../domain/entities/backup_record.dart';

/// Modal that makes the restore action deliberate: the user must confirm they
/// understand a restart is required and that the current data will be replaced
/// by a safety backup.
class RestoreConfirmDialog extends StatelessWidget {
  const RestoreConfirmDialog({super.key, required this.backup});

  final BackupRecord backup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Restore backup?'),
      content: Text(
        'This replaces the current school database with the backup '
        '"${backup.filename}". A safety copy of the current data is saved '
        'before replacing. The app must be restarted afterwards to load the '
        'restored data.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            foregroundColor: theme.colorScheme.onError,
            backgroundColor: theme.colorScheme.error,
          ),
          child: const Text('Restore'),
        ),
      ],
    );
  }
}
