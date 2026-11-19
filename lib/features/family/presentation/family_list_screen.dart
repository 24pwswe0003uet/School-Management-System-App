import 'package:flutter/material.dart';

import '../../settings/domain/services/settings_service.dart';
import '../../shared/theme/app_breakpoints.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_data_table.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_page_header.dart';
import '../../student/domain/services/student_service.dart';
import '../domain/entities/family_list_item.dart';
import '../domain/services/family_service.dart';
import 'family_details_screen.dart';
import 'family_form_screen.dart';
import 'widgets/family_card.dart';

/// Modern Family list with responsive desktop data table and mobile cards.
class FamilyListScreen extends StatefulWidget {
  const FamilyListScreen({
    super.key,
    required this.familyService,
    required this.studentService,
    required this.settingsService,
  });

  final FamilyService familyService;
  final StudentService studentService;
  final SettingsService settingsService;

  @override
  State<FamilyListScreen> createState() => _FamilyListScreenState();
}

class _FamilyListScreenState extends State<FamilyListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.familyService.query;
    widget.familyService.search(widget.familyService.query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openDetails(FamilyListItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyDetailsScreen(
          familyService: widget.familyService,
          studentService: widget.studentService,
          settingsService: widget.settingsService,
          familyId: item.family.id,
        ),
      ),
    );
    widget.familyService.refresh();
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyFormScreen(
          familyService: widget.familyService,
          studentService: widget.studentService,
          settingsService: widget.settingsService,
        ),
      ),
    );
    widget.familyService.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Scaffold(
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton.extended(
              key: const Key('family_add_fab'),
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: const Text('Add Family'),
            ),
      body: ListenableBuilder(
        listenable: widget.familyService,
        builder: (context, _) {
          final service = widget.familyService;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'Family Management',
                subtitle: '${service.results.length} registered family units',
                actions: [
                  FilledButton.icon(
                    key: const Key('family_add_desktop_btn'),
                    onPressed: _openCreate,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Family'),
                  ),
                ],
              ),
              // Filter Toolbar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: SizedBox(
                  maxWidth: 420,
                  child: TextField(
                    key: const Key('family_search_field'),
                    controller: _searchController,
                    onChanged: (value) => service.search(value),
                    decoration: InputDecoration(
                      hintText: 'Search by family ID, guardian, phone or student…',
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
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody(context, service, isDesktop)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, FamilyService service, bool isDesktop) {
    if (service.isLoading && service.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (service.error != null) {
      return AppErrorState(
        title: 'Could not load families',
        message: service.error!,
        onRetry: service.refresh,
      );
    }

    if (service.results.isEmpty) {
      return AppEmptyState(
        title: 'No families found',
        message: 'Try changing your search terms or add a new family.',
        actionLabel: 'Add Family',
        onAction: _openCreate,
      );
    }

    // Responsive Desktop Data Table
    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: AppDataTable(
          columns: const [
            DataColumn(label: Text('FAMILY ID')),
            DataColumn(label: Text('GUARDIAN NAME')),
            DataColumn(label: Text('RELATION')),
            DataColumn(label: Text('PRIMARY PHONE')),
            DataColumn(label: Text('ENROLLED CHILDREN')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: service.results.map((item) {
            final f = item.family;
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    f.code,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  InkWell(
                    onTap: () => _openDetails(item),
                    child: Text(
                      f.guardianName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(f.relationship ?? 'Guardian')),
                DataCell(Text(f.primaryPhone)),
                DataCell(
                  Text(
                    '${item.activeStudentCount} active (${item.totalStudentCount} total)',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    tooltip: 'View Family Details',
                    onPressed: () => _openDetails(item),
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
        return FamilyCard(item: item, onTap: () => _openDetails(item));
      },
    );
  }
}
