import 'package:flutter/material.dart';

import '../domain/entities/backup_record.dart';
import '../domain/exceptions.dart';
import '../domain/services/backup_service.dart';
import '../domain/services/data_export_service.dart';
import 'widgets/backup_banner.dart';
import 'widgets/backup_list.dart';
import 'widgets/restore_confirm_dialog.dart';

/// Module 13: Backup & Data Management.
///
/// Lets the school administrator create a verified backup of the live database,
/// export core data sets to Excel, and restore from an existing backup. The
/// whole screen is admin-only: a [BackupException] of permission type raised by
/// the service surfaces a permission banner instead of the controls.
class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    required this.service,
    required this.dataExportService,
  });

  final BackupService service;
  final DataExportService dataExportService;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  @override
  void initState() {
    super.initState();
    widget.service.reload();
  }

  Future<void> _createBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await widget.service.createBackup();
    if (!mounted) return;
    if (result.success) {
      messenger.showSnackBar(
        SnackBar(content: Text('Backup created: ${result.record?.filename}')),
      );
    } else {
      _showError(result.message ?? 'Could not create the backup.');
    }
  }

  Future<void> _restore(BackupRecord record) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => RestoreConfirmDialog(backup: record),
        ) ==
        true;
    if (!confirmed) return;

    try {
      final outcome = await widget.service.restore(record.path);
      if (!mounted) return;
      await _confirmRestart();
      if (outcome.success) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Database restored from ${record.filename}. '
              'A safety backup was saved.',
            ),
          ),
        );
      }
    } on BackupException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError('Restore failed: $e');
    }
  }

  Future<void> _deleteBackup(BackupRecord record) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete backup?'),
            content: Text('This permanently removes ${record.filename}.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ==
        true;
    if (!confirmed || !mounted) return;
    try {
      await widget.service.deleteBackup(record);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Backup deleted.')));
    } on BackupException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    }
  }

  Future<void> _export(String type) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = switch (type) {
      'students' => await widget.dataExportService.exportStudents(),
      'families' => await widget.dataExportService.exportFamilies(),
      'employees' => await widget.dataExportService.exportEmployees(),
      'fees' => await widget.dataExportService.exportFees(),
      'expenses' => await widget.dataExportService.exportExpenses(),
      'salaries' => await widget.dataExportService.exportSalaries(),
      _ => false,
    };
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Export saved.' : 'Export cancelled or nothing to export.',
        ),
      ),
    );
  }

  Future<void> _confirmRestart() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Restart required'),
          content: const Text(
            'The database has been restored. Restart the app to load the '
            'restored data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Could not complete the operation'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Data Management'),
        actions: [
          IconButton(
            tooltip: 'Show in folder',
            icon: const Icon(Icons.folder_open_rounded),
            onPressed: () async {
              final ok = await widget.service.showInFolder();
              if (ok && mounted) {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Opening backup folder.')),
                );
              }
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.service,
        builder: (context, _) {
          if (!widget.service.isAdmin) {
            return const BackupPermissionBanner();
          }
          return _Body(
            service: widget.service,
            onBackup: _createBackup,
            onRestore: _restore,
            onDelete: _deleteBackup,
            onExport: _export,
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.service,
    required this.onBackup,
    required this.onRestore,
    required this.onDelete,
    required this.onExport,
  });

  final BackupService service;
  final VoidCallback onBackup;
  final void Function(BackupRecord) onRestore;
  final void Function(BackupRecord) onDelete;
  final void Function(String) onExport;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: service.reload,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _BackupControls(onBackup: onBackup, onExport: onExport),
          const SizedBox(height: 24),
          const Text(
            'Existing backups',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (service.isLoading && service.backups.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (service.backups.isEmpty)
            const Center(child: Text('No backups found yet.'))
          else
            BackupList(
              backups: service.backups,
              latestPath: service.latestBackup?.path,
              onRestore: onRestore,
              onDelete: onDelete,
            ),
          if (service.error != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last error: ${service.error}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BackupControls extends StatelessWidget {
  const _BackupControls({required this.onBackup, required this.onExport});

  final VoidCallback onBackup;
  final void Function(String) onExport;

  static const _exportItems = [
    ('students', Icons.school_rounded, 'Students'),
    ('families', Icons.family_restroom, 'Families'),
    ('employees', Icons.badge_rounded, 'Employees'),
    ('fees', Icons.payments_rounded, 'Fees'),
    ('expenses', Icons.receipt_long_rounded, 'Expenses'),
    ('salaries', Icons.account_balance_rounded, 'Salaries'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          key: const Key('create_backup'),
          onPressed: onBackup,
          icon: const Icon(Icons.save_alt_rounded),
          label: const Text('Create backup now'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Data export',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in _exportItems)
              FilledButton.icon(
                key: Key('export_${item.$1}'),
                onPressed: () => onExport(item.$1),
                icon: Icon(item.$2),
                label: Text(item.$3),
              ),
          ],
        ),
      ],
    );
  }
}
