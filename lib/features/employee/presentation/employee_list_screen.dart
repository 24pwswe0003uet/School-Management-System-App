import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../salary/domain/services/salary_service.dart';
import '../../shared/theme/app_breakpoints.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/formatters.dart';
import '../../shared/widgets/app_data_table.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_page_header.dart';
import '../../shared/widgets/app_status_chip.dart';
import '../domain/entities/employee.dart';
import '../domain/entities/employee_category.dart';
import '../domain/entities/employee_status.dart';
import '../domain/services/employee_service.dart';
import 'employee_details_screen.dart';
import 'employee_form_screen.dart';
import 'widgets/employee_card.dart';

/// Modern Employee list with responsive desktop data table and mobile cards.
class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({
    super.key,
    required this.employeeService,
    required this.salaryService,
  });

  final EmployeeService employeeService;
  final SalaryService salaryService;

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.employeeService.query;
    widget.employeeService.search(widget.employeeService.query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmployeeFormScreen(
          employeeService: widget.employeeService,
          salaryService: widget.salaryService,
        ),
      ),
    );
    widget.employeeService.refresh();
  }

  Future<void> _openDetails(Employee employee) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmployeeDetailsScreen(
          employeeService: widget.employeeService,
          salaryService: widget.salaryService,
          employeeId: employee.id,
        ),
      ),
    );
    widget.employeeService.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Scaffold(
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton.extended(
              key: const Key('employee_add_fab'),
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: const Text('Add Staff'),
            ),
      body: ListenableBuilder(
        listenable: widget.employeeService,
        builder: (context, _) {
          final service = widget.employeeService;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'Staff Directory',
                subtitle: '${service.results.length} faculty and operational employees',
                actions: [
                  FilledButton.icon(
                    key: const Key('employee_add_desktop_btn'),
                    onPressed: _openCreate,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Staff'),
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
                        key: const Key('employee_search_field'),
                        controller: _searchController,
                        onChanged: (value) => service.search(value),
                        decoration: InputDecoration(
                          hintText: 'Search by ID, name, designation or phone…',
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
                      width: 170,
                      child: _FilterDropdown<EmployeeStatus>(
                        key: const Key('employee_status_filter'),
                        label: 'Status',
                        value: service.statusFilter,
                        items: const {
                          null: 'All statuses',
                          EmployeeStatus.active: 'Active',
                          EmployeeStatus.inactive: 'Inactive',
                        },
                        onChanged: service.setStatusFilter,
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: _FilterDropdown<EmployeeCategory>(
                        key: const Key('employee_category_filter'),
                        label: 'Category',
                        value: service.categoryFilter,
                        items: {
                          null: 'All categories',
                          for (final c in EmployeeService.categories) c: c.label,
                        },
                        onChanged: service.setCategoryFilter,
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

  Widget _buildBody(BuildContext context, EmployeeService service, bool isDesktop) {
    if (service.isLoading && service.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (service.error != null) {
      return AppErrorState(
        title: 'Could not load staff',
        message: service.error!,
        onRetry: service.refresh,
      );
    }

    if (service.results.isEmpty) {
      return AppEmptyState(
        title: 'No staff found',
        message: 'Try changing your search terms or filters, or add a staff member.',
        actionLabel: 'Add Staff',
        onAction: _openCreate,
      );
    }

    // Responsive Desktop Data Table
    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: AppDataTable(
          columns: const [
            DataColumn(label: Text('STAFF ID')),
            DataColumn(label: Text('NAME')),
            DataColumn(label: Text('DESIGNATION')),
            DataColumn(label: Text('CATEGORY')),
            DataColumn(label: Text('MONTHLY BASE SALARY')),
            DataColumn(label: Text('PHONE')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: service.results.map((e) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    e.employeeCode,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  InkWell(
                    onTap: () => _openDetails(e),
                    child: Text(
                      e.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(e.designation)),
                DataCell(Text(e.category.label)),
                DataCell(
                  Text(
                    Formatters.money(e.baseSalary),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(Text(e.primaryPhone)),
                DataCell(
                  AppStatusChip(
                    label: e.status.label,
                    isSuccess: e.status == EmployeeStatus.active,
                    isDanger: e.status == EmployeeStatus.inactive,
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    tooltip: 'View Staff Details',
                    onPressed: () => _openDetails(e),
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
        return EmployeeCard(employee: item, onTap: () => _openDetails(item));
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
  final Map<T?, String> items;
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
        child: DropdownButton<T?>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: [
            for (final entry in items.entries)
              DropdownMenuItem<T?>(
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
