import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../../family/domain/services/family_service.dart';
import '../../family/presentation/family_details_screen.dart';
import '../domain/entities/student.dart';
import '../domain/entities/student_details.dart';
import '../domain/services/student_service.dart';
import 'student_form_screen.dart';

/// Full student profile: personal, family, academic, status, fee summary, and
/// admission/academic history. History is read-only and never overwritten.
class StudentDetailsScreen extends StatefulWidget {
  const StudentDetailsScreen({
    super.key,
    required this.studentService,
    required this.familyService,
    required this.studentId,
  });

  final StudentService studentService;
  final FamilyService familyService;
  final int studentId;

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  StudentDetails? _details;
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
      final details = await widget.studentService.getStudentDetails(
        widget.studentId,
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
        builder: (_) => StudentFormScreen(
          studentService: widget.studentService,
          familyService: widget.familyService,
          existing: _details!.student,
        ),
      ),
    );
    if (updated != null) await _load();
  }

  Future<void> _changeStatus() async {
    final student = _details!.student;
    final selected = await showDialog<StudentStatus>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change status'),
        content: RadioGroup<StudentStatus>(
          groupValue: student.status,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final status in StudentStatus.values)
                RadioListTile<StudentStatus>(
                  key: Key('student_status_${status.dbValue}'),
                  title: Text(status.label),
                  value: status,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected != null && selected != student.status) {
      await widget.studentService.setStudentStatus(student.id, selected);
      await _load();
    }
  }

  Future<void> _openFamily() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyDetailsScreen(
          familyService: widget.familyService,
          studentService: widget.studentService,
          familyId: _details!.family.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Details')),
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
                'Student could not be loaded.',
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
    final student = details.student;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              student.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            _statusChip(theme, student.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          student.studentId,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle(theme, 'Personal Information'),
        const SizedBox(height: 8),
        _buildPersonalCard(theme, details),
        const SizedBox(height: 20),
        _sectionTitle(theme, 'Family Information'),
        const SizedBox(height: 8),
        _buildFamilyCard(theme, details),
        const SizedBox(height: 20),
        _sectionTitle(theme, 'Academic Information'),
        const SizedBox(height: 8),
        _buildAcademicCard(theme, details),
        const SizedBox(height: 20),
        _sectionTitle(theme, 'Fee Summary'),
        const SizedBox(height: 8),
        _buildFeeCard(theme, details),
        const SizedBox(height: 20),
        _sectionTitle(theme, 'Admission History'),
        const SizedBox(height: 8),
        _buildAdmissionHistory(theme, details),
        const SizedBox(height: 20),
        _sectionTitle(theme, 'Academic History'),
        const SizedBox(height: 8),
        _buildAcademicHistory(theme, details),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              key: const Key('student_edit'),
              onPressed: _edit,
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const Key('student_change_status'),
              onPressed: _changeStatus,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Change status'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildPersonalCard(ThemeData theme, StudentDetails details) {
    final student = details.student;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(theme, Icons.person, 'Full name', student.name),
            _infoRow(
              theme,
              Icons.person_outline,
              'Gender',
              student.gender?.label ?? '—',
            ),
            _infoRow(
              theme,
              Icons.cake_outlined,
              'Date of birth',
              student.dateOfBirth == null
                  ? '—'
                  : Formatters.date(student.dateOfBirth!),
            ),
            _infoRow(
              theme,
              Icons.confirmation_number_outlined,
              'Admission number',
              student.admissionNumber ?? '—',
            ),
            _infoRow(
              theme,
              Icons.event,
              'Admission date',
              student.admissionDate == null
                  ? '—'
                  : Formatters.date(student.admissionDate!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyCard(ThemeData theme, StudentDetails details) {
    final family = details.family;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(
              theme,
              Icons.family_restroom,
              'Family ID',
              family.familyId,
            ),
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
            if (family.address != null && family.address!.isNotEmpty)
              _infoRow(theme, Icons.home_outlined, 'Address', family.address!),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('student_open_family'),
                onPressed: _openFamily,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open family profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcademicCard(ThemeData theme, StudentDetails details) {
    final student = details.student;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(
              theme,
              Icons.class_outlined,
              'Class',
              student.className ?? '—',
            ),
            _infoRow(
              theme,
              Icons.view_module_outlined,
              'Section',
              student.section ?? '—',
            ),
            _infoRow(
              theme,
              Icons.flag_outlined,
              'Status',
              student.status.label,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeCard(ThemeData theme, StudentDetails details) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Outstanding fees', style: theme.textTheme.labelMedium),
                Text(
                  Formatters.money(details.outstandingFees),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: details.outstandingFees > 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (details.feeHistory.isEmpty)
              Text(
                'Fee records will appear here when the Fee module is added.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              )
            else
              for (var i = 0; i < details.feeHistory.length; i++) ...[
                if (i > 0) const Divider(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Formatters.monthYear(
                              details.feeHistory[i].periodStart,
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Expected ${Formatters.money(details.feeHistory[i].expected)}'
                            ' · Paid ${Formatters.money(details.feeHistory[i].paid)}'
                            ' · Due ${Formatters.money(details.feeHistory[i].due)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    _feeStatusChip(theme, details.feeHistory[i].status),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdmissionHistory(ThemeData theme, StudentDetails details) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: details.admissions.isEmpty
            ? Text(
                'No admission history.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              )
            : Column(
                children: [
                  for (var i = 0; i < details.admissions.length; i++) ...[
                    if (i > 0) const Divider(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                details.admissions[i].admissionId,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              [
                                Formatters.date(
                                  details.admissions[i].admissionDate,
                                ),
                                if (details.admissions[i].className != null &&
                                    details.admissions[i].className!.isNotEmpty)
                                  details.admissions[i].className!,
                                if (details.admissions[i].section != null &&
                                    details.admissions[i].section!.isNotEmpty)
                                  details.admissions[i].section!,
                              ].join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                        if (details.admissions[i].admissionNumber != null ||
                            (details.admissions[i].admissionFee ?? 0) > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (details.admissions[i].admissionNumber != null)
                                'No ${details.admissions[i].admissionNumber}',
                              if ((details.admissions[i].admissionFee ?? 0) > 0)
                                'Fee ${Formatters.money(details.admissions[i].admissionFee!)}',
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildAcademicHistory(ThemeData theme, StudentDetails details) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: details.history.isEmpty
            ? Text(
                'No class or status changes recorded yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              )
            : Column(
                children: [
                  for (var i = 0; i < details.history.length; i++) ...[
                    if (i > 0) const Divider(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              if (details.history[i].className != null &&
                                  details.history[i].className!.isNotEmpty)
                                details.history[i].className!,
                              if (details.history[i].section != null &&
                                  details.history[i].section!.isNotEmpty)
                                details.history[i].section!,
                            ].join(' · '),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _statusChip(
                          theme,
                          StudentStatus.fromDb(details.history[i].status),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        Formatters.date(details.history[i].changedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
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
            width: 140,
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

  static Widget _statusChip(ThemeData theme, StudentStatus status) {
    final color = switch (status) {
      StudentStatus.active => Colors.green.shade700,
      StudentStatus.left => theme.colorScheme.error,
      StudentStatus.transferred => Colors.blue.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static Widget _feeStatusChip(ThemeData theme, String status) {
    final color = switch (status) {
      'paid' => Colors.green.shade700,
      'partial' => Colors.orange.shade800,
      'cancelled' => theme.colorScheme.outline,
      _ => theme.colorScheme.error,
    };
    final label = status.isEmpty
        ? status
        : status[0].toUpperCase() + status.substring(1);
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
