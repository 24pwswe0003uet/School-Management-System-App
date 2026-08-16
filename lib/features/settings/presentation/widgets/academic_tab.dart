import 'package:flutter/material.dart';

import '../../domain/repositories/settings_repository.dart';
import '../../domain/services/settings_service.dart';

/// Academic tab: manage the canonical class and section lists. Rows are
/// deactivated (never deleted) so historical student records keep their text
/// values. Renaming can optionally update the students' stored value.
class AcademicTab extends StatelessWidget {
  const AcademicTab({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    final canEdit = settingsService.isAdmin;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _NamedListSection(
          kind: 'class',
          title: 'Classes',
          subtitle: 'Used by student forms and monthly fee generation.',
          canEdit: canEdit,
          items: settingsService.allClasses
              .map(
                (c) => _NamedItem(
                  id: c.id,
                  name: c.className,
                  isActive: c.isActive,
                  studentCount: c.activeStudentCount,
                ),
              )
              .toList(),
          onAdd: () => _addName(context, 'class'),
          onRename: (item) => _renameName(context, 'class', item),
          onToggle: (item, value) => _toggleActive(context, 'class', item, value),
        ),
        const Divider(height: 40),
        _NamedListSection(
          kind: 'section',
          title: 'Sections',
          subtitle: 'A global section list shared across all classes.',
          canEdit: canEdit,
          items: settingsService.allSections
              .map(
                (s) => _NamedItem(
                  id: s.id,
                  name: s.sectionName,
                  isActive: s.isActive,
                  studentCount: s.activeStudentCount,
                ),
              )
              .toList(),
          onAdd: () => _addName(context, 'section'),
          onRename: (item) => _renameName(context, 'section', item),
          onToggle: (item, value) => _toggleActive(context, 'section', item, value),
        ),
      ],
    );
  }

  Future<void> _addName(BuildContext context, String kind) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add $kind name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: Key('settings_add_${kind}_name'),
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: kind == 'class' ? 'Class name' : 'Section name',
              hintText: kind == 'class' ? 'e.g. Play Group' : 'e.g. A',
              border: const OutlineInputBorder(),
            ),
            validator: SettingsService.validateEntityName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('settings_add_confirm'),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (kind == 'class') {
        await settingsService.addClass(controller.text);
      } else {
        await settingsService.addSection(controller.text);
      }
      messenger.showSnackBar(SnackBar(content: Text('${kindName(kind)} added.')));
    } on SettingsValidationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _renameName(
    BuildContext context,
    String kind,
    _NamedItem item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: item.name);
    final formKey = GlobalKey<FormState>();
    var renameStudents = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Rename $kind'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: Key('settings_rename_${kind}_name'),
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: kind == 'class' ? 'Class name' : 'Section name',
                    border: const OutlineInputBorder(),
                  ),
                  validator: SettingsService.validateEntityName,
                ),
                if (item.studentCount > 0) ...[
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    key: Key('settings_rename_students_$kind'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Also update ${item.studentCount} active student '
                      '${item.studentCount == 1 ? 'record' : 'records'}',
                    ),
                    value: renameStudents,
                    onChanged: (v) =>
                        setDialogState(() => renameStudents = v ?? false),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('settings_rename_confirm'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      if (kind == 'class') {
        await settingsService.updateClass(
          id: item.id,
          className: controller.text,
          renameStudents: renameStudents,
        );
      } else {
        await settingsService.updateSection(
          id: item.id,
          sectionName: controller.text,
          renameStudents: renameStudents,
        );
      }
      messenger.showSnackBar(SnackBar(content: Text('${kindName(kind)} renamed.')));
    } on SettingsValidationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    String kind,
    _NamedItem item,
    bool value,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!value && item.studentCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Deactivate $kind?'),
          content: Text(
            '"${item.name}" is used by ${item.studentCount} active student '
            '${item.studentCount == 1 ? 'record' : 'records'}. Their records '
            'are kept, but this $kind will no longer be offered in forms.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('settings_deactivate_confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (kind == 'class') {
      await settingsService.setClassActive(item.id, value);
    } else {
      await settingsService.setSectionActive(item.id, value);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${item.name} ${value ? 'activated' : 'deactivated'}.',
        ),
      ),
    );
  }
}

String kindName(String kind) => kind == 'class' ? 'Class' : 'Section';

class _NamedItem {
  const _NamedItem({
    required this.id,
    required this.name,
    required this.isActive,
    required this.studentCount,
  });

  final int id;
  final String name;
  final bool isActive;
  final int studentCount;
}

class _NamedListSection extends StatelessWidget {
  const _NamedListSection({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.canEdit,
    required this.items,
    required this.onAdd,
    required this.onRename,
    required this.onToggle,
  });

  final String kind;
  final String title;
  final String subtitle;
  final bool canEdit;
  final List<_NamedItem> items;
  final Future<void> Function() onAdd;
  final Future<void> Function(_NamedItem item) onRename;
  final Future<void> Function(_NamedItem item, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyPrefix = 'settings_${kind}s';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (canEdit)
              OutlinedButton.icon(
                key: Key('${keyPrefix}_add'),
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text('Add ${kindName(kind)}'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No $title yet. Add the first one.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              : Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        key: Key('${keyPrefix}_${item.id}'),
                        title: Text(item.name),
                        subtitle: Text(
                          item.isActive
                              ? '${item.studentCount} active student '
                                    '${item.studentCount == 1 ? 'record' : 'records'}'
                              : 'Inactive',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canEdit) ...[
                              IconButton(
                                key: Key('${keyPrefix}_rename_${item.id}'),
                                tooltip: 'Rename',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => onRename(item),
                              ),
                              Switch(
                                key: Key('${keyPrefix}_toggle_${item.id}'),
                                value: item.isActive,
                                onChanged: (v) => onToggle(item, v),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
