import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../family/domain/services/family_service.dart';
import '../../settings/domain/services/settings_service.dart';
import '../../shared/theme/app_breakpoints.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_data_table.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_page_header.dart';
import '../../shared/widgets/app_status_chip.dart';
import '../domain/entities/student.dart';
import '../domain/services/student_service.dart';
import 'student_details_screen.dart';
import 'student_form_screen.dart';
import 'widgets/student_card.dart';

/// Modern Student list + responsive data table with fast search and class/section/status filters.
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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.studentService.query;
    widget.studentService.search(widget.studentService.query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Scaffold(
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton.extended(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'Student Directory',
                subtitle: '${service.results.length} students enrolled and tracked in records',
                actions: [
                  FilledButton.icon(
                    key: const Key('student_add_desktop_btn'),
                    onPressed: _openCreate,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Student'),
                  ),
                ],
              ),
              // Filter Toolbar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 320,
                      child: TextField(
                        key: const Key('student_search_field'),
                        controller: _searchController,
                        onChanged: (value) => service.search(value),
                        decoration: InputDecoration(
                          hintText: 'Search by ID, name, admission no, phone…',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    service.search('');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: _FilterDropdown<String>(
                        key: const Key('student_status_filter'),
                        label: 'Status',
                        value: service.statusFilter?.dbValue,
                        items: const {
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
                      width: 170,
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
                      width: 170,
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
              const SizedBox(height: 12),
              Expanded(child: _buildBody(context, service, isDesktop)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, StudentService service, bool isDesktop) {
    if (service.isLoading && service.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (service.error != null) {
      return AppErrorState(
        title: 'Could not load students',
        message: service.error!,
        onRetry: service.refresh,
      );
    }

    if (service.results.isEmpty) {
      return AppEmptyState(
        title: 'No students found',
        message: 'Try changing your search terms or filters, or add a new student.',
        actionLabel: 'Add Student',
        onAction: _openCreate,
      );
    }

    // Responsive Desktop Data Table
    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: AppDataTable(
          columns: const [
            DataColumn(label: Text('ADMISSION NO.')),
            DataColumn(label: Text('STUDENT NAME')),
            DataColumn(label: Text('CLASS & SECTION')),
            DataColumn(label: Text('GUARDIAN')),
            DataColumn(label: Text('PHONE')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: service.results.map((item) {
            final st = item.student;
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    st.admissionNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  InkWell(
                    onTap: () => _openDetails(st),
                    child: Text(
                      st.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                ),
                DataCell(Text('${st.className} ${st.sectionName}'.trim())),
                DataCell(Text(item.guardianName ?? '—')),
                DataCell(Text(item.guardianPhone ?? '—')),
                DataCell(
                  AppStatusChip(
                    label: st.status.label,
                    isSuccess: st.status == StudentStatus.active,
                    isWarning: st.status == StudentStatus.transferred,
                    isDanger: st.status == StudentStatus.left,
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    tooltip: 'View Profile',
                    onPressed: () => _openDetails(st),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      );
    }

    // Mobile / Tablet Card View
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: service.results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
