import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../../settings/domain/services/settings_service.dart';
import '../../student/domain/services/student_service.dart';
import '../../student/presentation/student_form_screen.dart';
import '../domain/entities/family_details.dart';
import '../domain/services/family_service.dart';
import 'family_form_screen.dart';

/// Family profile: record details, linked students, combined outstanding fees,
/// and actions (edit, archive/unarchive, delete when empty, add another child).
class FamilyDetailsScreen extends StatefulWidget {
  const FamilyDetailsScreen({
    super.key,
    required this.familyService,
    required this.studentService,
    required this.settingsService,
    required this.familyId,
  });

  final FamilyService familyService;
  final StudentService studentService;
  final SettingsService settingsService;
  final int familyId;

  @override
  State<FamilyDetailsScreen> createState() => _FamilyDetailsScreenState();
}

class _FamilyDetailsScreenState extends State<FamilyDetailsScreen> {
  FamilyDetails? _details;
  bool _loading = true;
  Object? _error;

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
      final details = await widget.familyService.getFamilyDetails(
        widget.familyId,
      );
      if (mounted) setState(() => _details = details);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FamilyFormScreen(
          familyService: widget.familyService,
          studentService: widget.studentService,
          settingsService: widget.settingsService,
          existing: _details!.family,
        ),
      ),
    );
    if (updated != null) await _load();
  }

  Future<void> _addChild() async {
    final family = _details!.family;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentFormScreen(
          studentService: widget.studentService,
          familyService: widget.familyService,
          settingsService: widget.settingsService,
          preselectedFamilyId: family.id,
        ),
      ),
    );
    await _load();
  }

  Future<void> _toggleArchive() async {
    final family = _details!.family;
    if (family.isArchived) {
      await widget.familyService.unarchiveFamily(family.id);
    } else {
      await widget.familyService.archiveFamily(family.id);
    }
    await _load();
  }

  Future<void> _delete() async {
    final family = _details!.family;
    if (_details!.students.isNotEmpty) {
      final archive = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Family cannot be deleted'),
          content: Text(
            '${family.familyId} has ${_details!.studentCount} linked '
            'student${_details!.studentCount == 1 ? '' : 's'}. Families with '
            'students are never deleted. You can archive it instead.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('family_archive_from_delete'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (archive == true) {
        await widget.familyService.archiveFamily(family.id);
        await _load();
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete family?'),
        content: Text(
          '${family.familyId} (${family.guardianName}) will be permanently '
          'deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('family_delete_confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.familyService.deleteFamily(family.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Details')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _details == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Family could not be loaded.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final details = _details!;
    final family = details.family;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(24),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final infoCard = _buildInfoCard(theme, details);
            final outstandingCard = _buildOutstandingCard(theme, details);
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  infoCard,
                  const SizedBox(height: 16),
                  outstandingCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: infoCard),
                const SizedBox(width: 16),
                outstandingCard,
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'Students (${details.studentCount})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              key: const Key('family_add_child'),
              onPressed: _addChild,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add another child'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (details.students.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No students linked to this family yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < details.students.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(details.students[i].name),
                    subtitle: Text(
                      [
                        details.students[i].studentId,
                        if (details.students[i].className != null)
                          details.students[i].className!,
                        if (details.students[i].section != null)
                          details.students[i].section!,
                      ].join(' · '),
                    ),
                    trailing: _statusChip(theme, details.students[i].status),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              key: const Key('family_edit'),
              onPressed: _edit,
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: const Key('family_archive'),
              onPressed: _toggleArchive,
              icon: Icon(
                family.isArchived ? Icons.unarchive : Icons.archive_outlined,
              ),
              label: Text(family.isArchived ? 'Unarchive' : 'Archive'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: const Key('family_delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ),
      ],
    ),
  ),
);
  }

  Widget _buildInfoCard(ThemeData theme, FamilyDetails details) {
    final family = details.family;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  family.familyId,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                _statusChip(theme, family.status.label),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow(theme, Icons.person, 'Guardian', family.guardianName),
            if (family.motherName != null && family.motherName!.isNotEmpty)
              _infoRow(
                theme,
                Icons.person_outline,
                'Mother',
                family.motherName!,
              ),
            if (family.primaryPhone != null && family.primaryPhone!.isNotEmpty)
              _infoRow(
                theme,
                Icons.phone,
                'Primary phone',
                family.primaryPhone!,
              ),
            if (family.secondaryPhone != null &&
                family.secondaryPhone!.isNotEmpty)
              _infoRow(
                theme,
                Icons.phone_outlined,
                'Secondary phone',
                family.secondaryPhone!,
              ),
            if (family.address != null && family.address!.isNotEmpty)
              _infoRow(theme, Icons.home_outlined, 'Address', family.address!),
            if (family.cnic != null && family.cnic!.isNotEmpty)
              _infoRow(theme, Icons.badge_outlined, 'CNIC', family.cnic!),
            if (family.notes != null && family.notes!.isNotEmpty)
              _infoRow(theme, Icons.notes, 'Notes', family.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildOutstandingCard(ThemeData theme, FamilyDetails details) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Family Outstanding Fees', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Text(
              Formatters.money(details.outstandingFees),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: details.outstandingFees > 0
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Combined dues for all linked students.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _statusChip(ThemeData theme, String status) {
    final isArchived = status == 'inactive' || status == 'archived';
    final label = isArchived
        ? 'Archived'
        : status.isEmpty
        ? status
        : status[0].toUpperCase() + status.substring(1);
    final color = isArchived
        ? theme.colorScheme.outline
        : Colors.green.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
