import 'package:flutter/material.dart';

import '../domain/entities/employee.dart';
import '../domain/entities/employee_category.dart';
import '../domain/entities/employee_status.dart';
import '../domain/services/employee_service.dart';
import '../../salary/domain/services/salary_service.dart';
import 'employee_details_screen.dart';
import 'employee_form_screen.dart';
import 'widgets/employee_card.dart';

/// Employee list + fast search with category/status filters.
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
  @override
  void initState() {
    super.initState();
    widget.employeeService.search(widget.employeeService.query);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Management')),
      floatingActionButton: FloatingActionButton.extended(
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
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  key: const Key('employee_search_field'),
                  onChanged: (value) => service.search(value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText:
                        'Search by employee ID, name, designation or phone…',
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
                      width: 160,
                      child: _FilterDropdown<EmployeeStatus>(
                        key: const Key('employee_status_filter'),
                        label: 'Status',
                        value: service.statusFilter,
                        items: {
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
                          for (final c in EmployeeService.categories)
                            c: c.label,
                        },
                        onChanged: service.setCategoryFilter,
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

  Widget _buildContent(EmployeeService service) {
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
                'Staff could not be loaded.',
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
                Icons.groups_outlined,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'No staff found.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Try a different search or filter, or use "Add Staff" to '
                'register someone.',
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
        final employee = service.results[index];
        return EmployeeCard(
          employee: employee,
          onTap: () => _openDetails(employee),
        );
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
        border: const OutlineInputBorder(),
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
