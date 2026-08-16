import 'package:flutter/material.dart';

import '../../domain/entities/backup_record.dart';

/// A compact list of existing backups, newest first, with restore/delete
/// actions. The most recent backup is highlighted as "Latest".
class BackupList extends StatelessWidget {
  const BackupList({
    super.key,
    required this.backups,
    required this.latestPath,
    required this.onRestore,
    required this.onDelete,
  });

  final List<BackupRecord> backups;
  final String? latestPath;
  final void Function(BackupRecord) onRestore;
  final void Function(BackupRecord) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final record in backups)
          ListTile(
            leading: Icon(
              record.status == BackupStatus.successful
                  ? Icons.check_circle_rounded
                  : record.status == BackupStatus.failed
                      ? Icons.warning_rounded
                      : Icons.inventory_rounded,
              color: record.status == BackupStatus.successful
                  ? Colors.green
                  : record.status == BackupStatus.failed
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: Text(record.filename),
            subtitle: Text(_subtitle(record, context)),
            trailing: OverflowBar(
              children: [
                IconButton(
                  tooltip: 'Restore',
                  icon: const Icon(Icons.restore_rounded),
                  onPressed: () => onRestore(record),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_rounded),
                  onPressed: () => onDelete(record),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _subtitle(BackupRecord record, BuildContext context) {
    final stamp = '${record.createdAt.year}/'
        '${record.createdAt.month.toString().padLeft(2, '0')}/'
        '${record.createdAt.day.toString().padLeft(2, '0')} '
        '${record.createdAt.hour.toString().padLeft(2, '0')}:'
        '${record.createdAt.minute.toString().padLeft(2, '0')}';
    final latest = record.path == latestPath ? ' • Latest' : '';
    return '$stamp • ${record.sizeBytes} bytes$latest';
  }
}
