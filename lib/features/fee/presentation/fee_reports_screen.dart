import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../application/fee_service.dart';
import '../domain/entities/family_outstanding_row.dart';
import '../domain/entities/fee_period.dart';
import '../domain/entities/fee_record.dart';
import '../domain/entities/fee_student_pick.dart';
import '../domain/entities/monthly_collection_report.dart';
import '../domain/entities/unpaid_student_row.dart';
import 'fee_record_detail_screen.dart';
import 'widgets/fee_status_chip.dart';
import 'widgets/month_period_picker.dart';

/// The five key fee reports: monthly collection, unpaid students, total
/// outstanding, family outstanding and a student's fee history.
class FeeReportsScreen extends StatefulWidget {
  const FeeReportsScreen({super.key, required this.feeService});

  final FeeService feeService;

  @override
  State<FeeReportsScreen> createState() => _FeeReportsScreenState();
}

class _FeeReportsScreenState extends State<FeeReportsScreen> {
  FeePeriod _period = FeePeriod.current();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fee Reports'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Collection'),
              Tab(text: 'Unpaid'),
              Tab(text: 'Outstanding'),
              Tab(text: 'Families'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: MonthPeriodPicker(
                period: _period,
                onChanged: (period) => setState(() => _period = period),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _CollectionTab(
                    key: ValueKey(_period),
                    feeService: widget.feeService,
                    period: _period,
                  ),
                  _UnpaidTab(
                    key: ValueKey(_period),
                    feeService: widget.feeService,
                    period: _period,
                  ),
                  _OutstandingTab(feeService: widget.feeService),
                  _FamiliesTab(feeService: widget.feeService),
                  _HistoryTab(feeService: widget.feeService),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportScaffold extends StatelessWidget {
  const _ReportScaffold({
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.child,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return child;
  }
}

class _CollectionTab extends StatefulWidget {
  const _CollectionTab({super.key, required this.feeService, required this.period});

  final FeeService feeService;
  final FeePeriod period;

  @override
  State<_CollectionTab> createState() => _CollectionTabState();
}

class _CollectionTabState extends State<_CollectionTab> {
  MonthlyCollectionReport? _report;
  bool _loading = true;
  String? _error;

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
      final report = await widget.feeService.repository.monthlyCollection(
        year: widget.period.year,
        month: widget.period.month,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'The collection report could not be loaded.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = _report;
    return _ReportScaffold(
      loading: _loading,
      error: _error,
      onRetry: _load,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Collected in ${widget.period.label}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  Formatters.money(report?.collected ?? 0),
                  key: const Key('report_collected_amount'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${report?.paymentCount ?? 0} payments (reversed excluded)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnpaidTab extends StatefulWidget {
  const _UnpaidTab({super.key, required this.feeService, required this.period});

  final FeeService feeService;
  final FeePeriod period;

  @override
  State<_UnpaidTab> createState() => _UnpaidTabState();
}

class _UnpaidTabState extends State<_UnpaidTab> {
  List<UnpaidStudentRow> _rows = const [];
  bool _loading = true;
  String? _error;

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
      final rows = await widget.feeService.repository
          .unpaidStudents(widget.period);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'The unpaid list could not be loaded.';
        _loading = false;
      });
    }
  }

  Future<void> _open(UnpaidStudentRow row) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FeeRecordDetailScreen(
          feeService: widget.feeService,
          recordId: row.record.id,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ReportScaffold(
      loading: _loading,
      error: _error,
      onRetry: _load,
      child: _rows.isEmpty
          ? Center(
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
                    'Everyone paid ${widget.period.label}.',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = _rows[index];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    key: Key('unpaid_${row.record.id}'),
                    onTap: () => _open(row),
                    title: Text(
                      row.studentName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      [
                        row.studentId,
                        if (row.className != null) 'Class ${row.className}',
                        if (row.guardianName != null) row.guardianName!,
                      ].join(' · '),
                    ),
                    trailing: Text(
                      Formatters.money(row.record.remainingAmount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _OutstandingTab extends StatefulWidget {
  const _OutstandingTab({required this.feeService});

  final FeeService feeService;

  @override
  State<_OutstandingTab> createState() => _OutstandingTabState();
}

class _OutstandingTabState extends State<_OutstandingTab> {
  double? _total;
  bool _loading = true;
  String? _error;

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
      final total = await widget.feeService.repository.totalOutstanding();
      if (!mounted) return;
      setState(() {
        _total = total;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Outstanding could not be loaded.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ReportScaffold(
      loading: _loading,
      error: _error,
      onRetry: _load,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Total outstanding fees',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  Formatters.money(_total ?? 0),
                  key: const Key('report_outstanding_amount'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Across all unpaid and partially paid records.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FamiliesTab extends StatefulWidget {
  const _FamiliesTab({required this.feeService});

  final FeeService feeService;

  @override
  State<_FamiliesTab> createState() => _FamiliesTabState();
}

class _FamiliesTabState extends State<_FamiliesTab> {
  List<FamilyOutstandingRow> _rows = const [];
  bool _loading = true;
  String? _error;

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
      final rows = await widget.feeService.repository.familyOutstanding();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Family balances could not be loaded.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ReportScaffold(
      loading: _loading,
      error: _error,
      onRetry: _load,
      child: _rows.isEmpty
          ? Center(
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
                    'No family has an outstanding balance.',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = _rows[index];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    key: Key('family_outstanding_${row.familyId}'),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.guardianName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          Formatters.money(row.outstanding),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${row.familyCode} · ${row.studentCount} '
                      'student${row.studentCount == 1 ? '' : 's'}',
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({required this.feeService});

  final FeeService feeService;

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  List<FeeStudentPick> _matches = const [];
  List<FeeRecord> _history = const [];
  FeeStudentPick? _selected;
  bool _searching = false;
  bool _loadingHistory = false;
  String? _error;
  String? _lastQuery;

  Future<void> _search(String query) async {
    _lastQuery = query.trim();
    if (_lastQuery!.isEmpty) {
      setState(() {
        _matches = [];
        _selected = null;
        _history = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _selected = null;
      _history = [];
      _error = null;
    });
    try {
      final matches = await widget.feeService.repository
          .searchStudents(query, limit: 8);
      if (!mounted) return;
      setState(() {
        _matches = matches;
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

  Future<void> _pick(FeeStudentPick student) async {
    setState(() {
      _selected = student;
      _loadingHistory = true;
      _history = [];
      _error = null;
    });
    try {
      final history = await widget.feeService.repository
          .studentFeeHistory(student.id);
      if (!mounted) return;
      setState(() {
        _history = history;
        _loadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'The fee history could not be loaded.';
        _loadingHistory = false;
      });
    }
  }

  void _retry() {
    if (_selected != null) {
      _pick(_selected!);
    } else if (_lastQuery != null && _lastQuery!.isNotEmpty) {
      _search(_lastQuery!);
    }
  }

  Future<void> _open(FeeRecord record) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FeeRecordDetailScreen(
          feeService: widget.feeService,
          recordId: record.id,
        ),
      ),
    );
    if (_selected != null) {
      await _pick(_selected!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            key: const Key('history_student_search'),
            onChanged: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search a student…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(child: _buildBody(theme)),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_error != null) {
      return _ReportScaffold(
        loading: false,
        error: _error,
        onRetry: _retry,
        child: const SizedBox.shrink(),
      );
    }
    if (_selected != null) {
      if (_loadingHistory) {
        return const Center(child: CircularProgressIndicator());
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                _selected!.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                [
                  _selected!.studentId,
                  if (_selected!.className != null)
                    'Class ${_selected!.className}',
                ].join(' · '),
              ),
              trailing: IconButton(
                key: const Key('history_change_student'),
                icon: const Icon(Icons.close),
                tooltip: 'Change student',
                onPressed: () => setState(() {
                  _selected = null;
                  _history = [];
                }),
              ),
            ),
          ),
          Expanded(
            child: _history.isEmpty
                ? Center(
                    child: Text(
                      'No fee records for this student.',
                      style: theme.textTheme.titleMedium,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _history.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final record = _history[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          key: Key('history_record_${record.id}'),
                          onTap: () => _open(record),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  record.period.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              FeeStatusChip(status: record.status),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Paid ${Formatters.money(record.paidAmount)} · '
                              'Remaining '
                              '${Formatters.money(record.remainingAmount)}',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    }
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_rounded,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'Search a student to see their fee history.',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _matches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final student = _matches[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            key: Key('history_student_${student.id}'),
            title: Text(student.name),
            subtitle: Text(
              [
                student.studentId,
                if (student.className != null) 'Class ${student.className}',
              ].join(' · '),
            ),
            onTap: () => _pick(student),
          ),
        );
      },
    );
  }
}
