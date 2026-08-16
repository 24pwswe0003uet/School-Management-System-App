import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../../settings/domain/services/settings_service.dart';
import '../application/fee_service.dart';
import '../domain/entities/fee_record.dart';
import '../domain/entities/fee_student_pick.dart';
import 'widgets/collect_payment_flow.dart';
import 'widgets/fee_status_chip.dart';

/// Records a payment: search an active student → pick an open monthly charge →
/// enter the amount/date/receipt/note → receipt is shown and printable.
class CollectPaymentScreen extends StatefulWidget {
  const CollectPaymentScreen({
    super.key,
    required this.feeService,
    required this.settingsService,
  });

  final FeeService feeService;
  final SettingsService settingsService;

  @override
  State<CollectPaymentScreen> createState() => _CollectPaymentScreenState();
}

class _CollectPaymentScreenState extends State<CollectPaymentScreen> {
  List<FeeStudentPick> _students = [];
  bool _searching = false;
  FeeStudentPick? _selected;
  List<FeeRecord> _records = [];
  bool _loadingRecords = false;
  String? _error;
  String? _lastQuery;

  Future<void> _search(String query) async {
    _lastQuery = query.trim();
    if (_lastQuery!.isEmpty) {
      setState(() {
        _students = [];
        _selected = null;
        _records = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _selected = null;
      _records = [];
      _error = null;
    });
    try {
      final results = await widget.feeService.repository.searchStudents(query);
      if (!mounted) return;
      setState(() {
        _students = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Student search could not be loaded.';
        _searching = false;
      });
    }
  }

  Future<void> _select(FeeStudentPick student) async {
    setState(() {
      _selected = student;
      _loadingRecords = true;
      _records = [];
      _error = null;
    });
    try {
      final records = await widget.feeService.repository
          .listOpenFeeRecords(student.id);
      if (!mounted) return;
      setState(() {
        _records = records;
        _loadingRecords = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Open fee charges could not be loaded.';
        _loadingRecords = false;
      });
    }
  }

  void _retry() {
    if (_selected != null) {
      _select(_selected!);
    } else if (_lastQuery != null && _lastQuery!.isNotEmpty) {
      _search(_lastQuery!);
    }
  }

  Future<void> _collect(FeeRecord record) async {
    await runCollectPaymentFlow(
      context,
      feeService: widget.feeService,
      settingsService: widget.settingsService,
      record: record,
    );
    if (!mounted) return;
    if (_selected != null) {
      await _select(_selected!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Collect Payment')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              key: const Key('collect_student_search'),
              onChanged: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by student ID, name, family or admission…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_selected != null) {
      return _buildSelected(theme);
    }
    if (_error != null) {
      return _errorView(theme);
    }
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.payments_rounded,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'Search for the student who is paying.',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _students.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final student = _students[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            key: Key('collect_student_${student.id}'),
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(
              student.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              [
                student.studentId,
                if (student.className != null) 'Class ${student.className}',
                if (student.section != null) student.section,
                if (student.guardianName != null) student.guardianName,
              ].join(' · '),
            ),
            onTap: () => _select(student),
          ),
        );
      },
    );
  }

  Widget _buildSelected(ThemeData theme) {
    final student = _selected!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(
              student.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              [
                student.studentId,
                if (student.className != null) 'Class ${student.className}',
              ].join(' · '),
            ),
            trailing: IconButton(
              key: const Key('collect_change_student'),
              tooltip: 'Change student',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _selected = null;
                _records = [];
              }),
            ),
          ),
        ),
        if (_error != null) ...[
          Expanded(child: _errorView(theme)),
        ] else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Open fee charges',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: _buildRecords(theme)),
        ],
      ],
    );
  }

  Widget _errorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something went wrong.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecords(ThemeData theme) {
    if (_loadingRecords) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'No outstanding charges for this student.',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = _records[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            key: Key('collect_record_${record.id}'),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    record.period.label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                FeeStatusChip(status: record.status),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Net ${Formatters.money(record.netPayable)} · '
                'Paid ${Formatters.money(record.paidAmount)} · '
                'Remaining ${Formatters.money(record.remainingAmount)}',
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _collect(record),
          ),
        );
      },
    );
  }
}
