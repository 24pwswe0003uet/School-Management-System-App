import 'package:flutter/material.dart';

import '../../settings/domain/services/settings_service.dart';
import '../../student/domain/services/student_service.dart';
import '../domain/entities/family_list_item.dart';
import '../domain/services/family_service.dart';
import 'family_details_screen.dart';
import 'family_form_screen.dart';
import 'widgets/family_card.dart';

/// Family list + search. Reaches the create form and the family profile.
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
  @override
  void initState() {
    super.initState();
    widget.familyService.search(widget.familyService.query);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Family Management')),
      floatingActionButton: FloatingActionButton.extended(
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
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  key: const Key('family_search_field'),
                  onChanged: (value) => service.search(value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText:
                        'Search by family ID, guardian, phone or student…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(child: _buildContent(service)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(FamilyService service) {
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
                'Families could not be loaded.',
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
                Icons.family_restroom,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'No families found yet.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Use "Add Family" to create the first record.',
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
        return FamilyCard(item: item, onTap: () => _openDetails(item));
      },
    );
  }
}
