import 'package:flutter/material.dart';

import '../../family/domain/services/family_service.dart';
import '../../settings/domain/services/settings_service.dart';
import '../domain/entities/student.dart';
import '../domain/services/student_service.dart';
import 'student_details_screen.dart';
import 'student_form_screen.dart';
import 'widgets/student_card.dart';

/// Student list + fast search with class/section/status filters.
class StudentListScreen extends StatefulWidget {
  const StudentListScreen({
    super.key,
    required this.studentService,
    required this.familyService,
    required this.settingsService,
  });

  final StudentService studentService;
  final FamilyService familyService;
  final SettingsService settingsService;

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  @override
  void initState() {
    super.initState();
    widget.studentService.search(widget.studentService.query);
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentFormScreen(
          studentService: widget.studentService,
          familyService: widget.familyService,
          settingsService: widget.settingsService,
        ),
      ),
    );
    widget.studentService.refresh();
  }

  Future<void> _openDetails(Student student) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentDetailsScreen(
          studentService: widget.studentService,
          familyService: widget.familyService,
          settingsService: widget.settingsService,
          studentId: student.id,
        ),
      ),
    );
    widget.studentService.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Management')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('student_add_fab'),
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Add Student'),
      ),
      body: ListenableBuilder(
        listenable: widget.studentService,
        builder: (context, _) {
          final service = widget.studentService;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  key: const Key('student_search_field'),
                  onChanged: (value) => service.search(value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText:
                        'Search by Student ID, name, admission no., family, '
                        'guardian or phone…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 170,
                      child: _FilterDropdown<String>(
                        key: const Key('student_status_filter'),
                        label: 'Status',
                        value: service.statusFilter?.dbValue,
                        items: {
                          'all': 'All statuses',
                          'active': 'Active',
                          'left': 'Left',
                          'transferred': 'Transferred',
                        },
                        onChanged: (value) => service.setStatusFilter(
                          value == 'all' ? null : StudentStatus.fromDb(value),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: _FilterDropdown<String>(
                        key: const Key('student_class_filter'),
                        label: 'Class',
                        value: service.classFilter ?? 'all',
                        items: {
                          'all': 'All classes',
                          for (final c in service.classes) c: c,
                        },
                        onChanged: (value) => service.setClassFilter(
                          value == 'all' ? null : value,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: _FilterDropdown<String>(
                        key: const Key('student_section_filter'),
                        label: 'Section',
                        value: service.sectionFilter ?? 'all',
                        items: {
                          'all': 'All sections',
                          for (final s in service.sections) s: s,
                        },
                        onChanged: (value) => service.setSectionFilter(
                          value == 'all' ? null : value,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildContent(service)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(StudentService service) {
    final theme = Theme.of(context);
    if (service.isLoading && service.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (service.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Students could not be loaded.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: service.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (service.results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.school_rounded,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text('No students found.', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Try a different search, or use "Add Student" to register one.',
                textAlign: TextAlign.center,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: service.results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = service.results[index];
        return StudentCard(item: item, onTap: () => _openDetails(item.student));
      },
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: [
            for (final entry in items.entries)
              DropdownMenuItem<T>(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
