import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../family/domain/entities/family.dart';
import '../../family/domain/entities/family_list_item.dart';
import '../../family/domain/services/family_service.dart';
import '../../family/presentation/family_form_screen.dart';
import '../../settings/domain/services/settings_service.dart';
import '../../student/domain/entities/student.dart';
import '../../student/domain/entities/student_list_item.dart';
import '../../student/domain/services/student_service.dart';
import '../../student/presentation/student_details_screen.dart';
import 'admission_success_screen.dart';

sealed class _DupDecision {
  const _DupDecision();
}

class _DupContinue extends _DupDecision {
  const _DupContinue();
}

class _DupInspect extends _DupDecision {
  const _DupInspect(this.student);
  final Student student;
}

/// Module 5: the controlled New Admission workflow. The operator searches for
/// (or creates) an existing family, enters the student and admission details
/// (with duplicate warnings), reviews everything, and confirms. Saving writes
/// the student + admission record in one transaction; the success screen then
/// offers to open the student, start a new admission or return to the
/// dashboard.
class AdmissionWizardScreen extends StatefulWidget {
  const AdmissionWizardScreen({
    super.key,
    required this.studentService,
    required this.familyService,
    required this.settingsService,
  });

  final StudentService studentService;
  final FamilyService familyService;
  final SettingsService settingsService;

  @override
  State<AdmissionWizardScreen> createState() => _AdmissionWizardScreenState();
}

class _AdmissionWizardScreenState extends State<AdmissionWizardScreen> {
  final _formKey = GlobalKey<FormState>();

  int _step = 0;
  Family? _family;
  String? _familyError;

  bool _pickingFamily = true;
  List<FamilyListItem> _familyResults = const [];
  bool _familyLoading = false;
  String _familyQuery = '';

  late final TextEditingController _name;
  late final TextEditingController _dob;
  late final TextEditingController _admissionNumber;
  late final TextEditingController _admissionDate;
  late final TextEditingController _fee;
  late final TextEditingController _notes;

  StudentGender? _gender;
  String? _className;
  String? _sectionName;
  String? _studentId;
  bool _checking = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final today = _isoDate(DateTime.now());
    _name = TextEditingController();
    _dob = TextEditingController();
    _admissionNumber = TextEditingController();
    _admissionDate = TextEditingController(text: today);
    _fee = TextEditingController();
    _notes = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFamilies('');
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _dob.dispose();
    _admissionNumber.dispose();
    _admissionDate.dispose();
    _fee.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _searchFamilies(String query) async {
    setState(() {
      _familyQuery = query;
      _familyLoading = true;
    });
    try {
      final results = await widget.familyService.findFamilies(query);
      if (mounted) setState(() => _familyResults = results);
    } finally {
      if (mounted) setState(() => _familyLoading = false);
    }
  }

  Future<void> _createFamily() async {
    final created = await Navigator.of(context).push<Family>(
      MaterialPageRoute(
        builder: (_) => FamilyFormScreen(
          familyService: widget.familyService,
          studentService: widget.studentService,
          settingsService: widget.settingsService,
        ),
      ),
    );
    if (created != null && mounted) {
      setState(() {
        _family = created;
        _familyError = null;
        _pickingFamily = false;
      });
    }
  }

  void _selectFamily(FamilyListItem item) {
    setState(() {
      _family = item.family;
      _familyError = null;
      _pickingFamily = false;
    });
  }

  void _changeFamily() {
    setState(() {
      _pickingFamily = true;
      _familyResults = const [];
    });
    _searchFamilies('');
  }

  Future<void> _startDetails() async {
    final id = await widget.studentService.nextStudentId();
    final admissionId = await widget.studentService.nextAdmissionId();
    if (!mounted) return;
    setState(() {
      _studentId = id;
      if (_admissionNumber.text.trim().isEmpty) {
        _admissionNumber.text = admissionId;
      }
      _step = 1;
    });
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the student full name.';
    }
    return null;
  }

  String? _validateDate(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) {
      return 'Use YYYY-MM-DD.';
    }
    if (DateTime.tryParse(v) == null) return 'Enter a valid date (YYYY-MM-DD).';
    return null;
  }

  String? _validateFee(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final parsed = double.tryParse(v);
    if (parsed == null || parsed < 0) {
      return 'Enter a valid amount (0 or more).';
    }
    return null;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) controller.text = _isoDate(picked);
  }

  /// Active classes from School Settings, plus the current value when it is no
  /// longer in the list (legacy free-text values stay editable).
  List<String> _classOptions() {
    final active = widget.settingsService.activeClasses
        .map((c) => c.className)
        .toList();
    final current = _className;
    if (current != null && current.isNotEmpty && !active.contains(current)) {
      return [...active, current];
    }
    return active;
  }

  List<String> _sectionOptions() {
    final active = widget.settingsService.activeSections
        .map((s) => s.sectionName)
        .toList();
    final current = _sectionName;
    if (current != null && current.isNotEmpty && !active.contains(current)) {
      return [...active, current];
    }
    return active;
  }

  Future<void> _continueToReview() async {
    if (!_formKey.currentState!.validate()) return;
    final family = _family!;
    setState(() => _checking = true);
    List<StudentListItem> matches;
    try {
      matches = await widget.studentService.findPossibleStudentDuplicates(
        name: _name.text,
        admissionNumber: _admissionNumber.text,
        familyId: family.id,
        guardianName: family.guardianName,
        primaryPhone: family.primaryPhone,
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
    if (!mounted) return;
    if (matches.isNotEmpty) {
      final decision = await _showDuplicateDialog(matches);
      if (!mounted) return;
      if (decision == null) return;
      if (decision is _DupInspect) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StudentDetailsScreen(
              studentService: widget.studentService,
              familyService: widget.familyService,
              settingsService: widget.settingsService,
              studentId: decision.student.id,
            ),
          ),
        );
        return;
      }
    }
    setState(() => _step = 2);
  }

  Future<_DupDecision?> _showDuplicateDialog(List<StudentListItem> duplicates) {
    return showDialog<_DupDecision>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Possible existing students'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Similar student records were found before this admission. '
                  'Review them to avoid duplicates.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    itemCount: duplicates.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = duplicates[index];
                      final s = item.student;
                      return ListTile(
                        key: ValueKey('adm_dup_${s.studentId}'),
                        dense: true,
                        leading: const Icon(Icons.school_rounded),
                        title: Text(s.name),
                        subtitle: Text(
                          [
                            s.studentId,
                            item.familyId,
                            if (s.className != null && s.className!.isNotEmpty)
                              s.className!,
                          ].join(' · '),
                        ),
                        trailing: const Text('View'),
                        onTap: () => Navigator.of(context).pop(_DupInspect(s)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('adm_dup_cancel'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('adm_dup_continue'),
              onPressed: () => Navigator.of(context).pop(const _DupContinue()),
              child: const Text('Continue anyway'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirm() async {
    final family = _family!;
    setState(() => _saving = true);
    try {
      final created = await widget.studentService.createStudent(
        familyId: family.id,
        name: _name.text,
        gender: _gender,
        dateOfBirth: _parseIsoDate(_dob.text),
        admissionNumber: _admissionNumber.text,
        admissionDate: _parseIsoDate(_admissionDate.text),
        className: (_className ?? '').trim(),
        section: (_sectionName ?? '').trim(),
        notes: _notes.text,
        admissionFee: double.tryParse(_fee.text.trim()) ?? 0,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AdmissionSuccessScreen(
            studentService: widget.studentService,
            familyService: widget.familyService,
            settingsService: widget.settingsService,
            student: created,
            family: family,
            admissionNumber: _admissionNumber.text.trim(),
            admissionFee: double.tryParse(_fee.text.trim()) ?? 0,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not save the admission. Please try again.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Admission')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStepIndicator(context),
                const SizedBox(height: 20),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildStep(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context) {
    const labels = ['Family', 'Student details', 'Review'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= _step
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
              ),
            ),
          Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: i <= _step
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: i <= _step ? Colors.white : null,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: i == _step
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  fontWeight: i == _step ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStep() {
    final theme = Theme.of(context);
    switch (_step) {
      case 0:
        return _buildFamilyStep(theme);
      case 1:
        return _buildDetailsStep(theme);
      default:
        return _buildReviewStep(theme);
    }
  }

  Widget _buildFamilyStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 1 of 3 — Existing family',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'The student must belong to a family. Search for an existing one '
          'or create it now.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 20),
        if (_family != null && !_pickingFamily)
          _buildSelectedFamily(theme)
        else ...[
          TextField(
            key: const Key('adm_family_search'),
            onChanged: _searchFamilies,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search family by ID, guardian or phone…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          if (_familyLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_familyResults.isEmpty)
            Text(
              _familyQuery.trim().isEmpty
                  ? 'No family exists yet.'
                  : 'No matching families.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < _familyResults.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      key: ValueKey(
                        'adm_family_pick_${_familyResults[i].family.familyId}',
                      ),
                      dense: true,
                      leading: const Icon(Icons.family_restroom),
                      title: Text(_familyResults[i].family.guardianName),
                      subtitle: Text(
                        [
                          _familyResults[i].family.familyId,
                          if (_familyResults[i].family.primaryPhone != null &&
                              _familyResults[i].family.primaryPhone!.isNotEmpty)
                            _familyResults[i].family.primaryPhone!,
                        ].join(' · '),
                      ),
                      onTap: () => _selectFamily(_familyResults[i]),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('adm_create_family'),
            onPressed: _createFamily,
            icon: const Icon(Icons.family_restroom),
            label: const Text('Create a new family'),
          ),
          if (_familyError != null) ...[
            const SizedBox(height: 8),
            Text(
              _familyError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const Key('adm_family_next'),
            onPressed: _family == null ? null : _startDetails,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next'),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedFamily(ThemeData theme) {
    final family = _family!;
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.family_restroom),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    family.familyId,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      family.guardianName,
                      if (family.primaryPhone != null &&
                          family.primaryPhone!.isNotEmpty)
                        family.primaryPhone!,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(
              key: const Key('adm_change_family'),
              onPressed: _changeFamily,
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsStep(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step 2 of 3 — Student details',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'The Student ID is generated automatically. Possible duplicate '
            'records are checked before the review.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 20),
          if (_studentId != null) ...[
            Text('Student ID', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              _studentId!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
          ],
          TextFormField(
            key: const Key('adm_name'),
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Full name *',
              border: OutlineInputBorder(),
            ),
            validator: _validateName,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<StudentGender?>(
            key: const Key('adm_gender'),
            initialValue: _gender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<StudentGender?>(
                value: null,
                child: Text('Select gender'),
              ),
              for (final gender in StudentGender.values)
                DropdownMenuItem<StudentGender?>(
                  value: gender,
                  child: Text(gender.label),
                ),
            ],
            onChanged: (value) => setState(() => _gender = value),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('adm_dob'),
                  controller: _dob,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    hintText: 'YYYY-MM-DD',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  validator: _validateDate,
                  onTap: () => _pickDate(_dob),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  key: const Key('adm_admission_date'),
                  controller: _admissionDate,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Admission date',
                    hintText: 'YYYY-MM-DD',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  validator: _validateDate,
                  onTap: () => _pickDate(_admissionDate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const Key('adm_class'),
                  initialValue: _className,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Select class'),
                    ),
                    for (final name in _classOptions())
                      DropdownMenuItem<String>(
                        value: name,
                        child: Text(name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _className = value),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const Key('adm_section'),
                  initialValue: _sectionName,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Section',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Select section'),
                    ),
                    for (final name in _sectionOptions())
                      DropdownMenuItem<String>(
                        value: name,
                        child: Text(name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _sectionName = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('adm_admission_number'),
                  controller: _admissionNumber,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Admission number',
                    hintText: 'Suggested automatically',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  key: const Key('adm_fee'),
                  controller: _fee,
                  textInputAction: TextInputAction.next,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Admission fee',
                    hintText: 'e.g. 5000',
                    border: OutlineInputBorder(),
                    prefixText: 'Rs ',
                  ),
                  validator: _validateFee,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('adm_notes'),
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                key: const Key('adm_details_back'),
                onPressed: () => setState(() => _step = 0),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
              LoadingButton(
                key: const Key('adm_details_continue'),
                label: 'Continue',
                icon: Icons.arrow_forward,
                isLoading: _checking,
                onPressed: _continueToReview,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(ThemeData theme) {
    final family = _family!;
    final fee = double.tryParse(_fee.text.trim()) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 3 of 3 — Review & confirm',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Confirm the admission. Saving creates the student and its '
          'admission record in a single transaction.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 20),
        _reviewRow(theme, 'Family', [
          family.familyId,
          family.guardianName,
          if (family.primaryPhone != null && family.primaryPhone!.isNotEmpty)
            family.primaryPhone!,
        ]),
        _reviewRow(theme, 'Student', [?_studentId, _name.text.trim()]),
        _reviewRow(theme, 'Class', [(_className ?? '').trim()]),
        _reviewRow(theme, 'Section', [(_sectionName ?? '').trim()]),
        _reviewRow(theme, 'Admission date', [_admissionDate.text.trim()]),
        _reviewRow(theme, 'Admission number', [_admissionNumber.text.trim()]),
        _reviewRow(theme, 'Admission fee', [
          fee > 0 ? Formatters.money(fee) : '—',
        ]),
        if (_notes.text.trim().isNotEmpty)
          _reviewRow(theme, 'Notes', [_notes.text.trim()]),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              key: const Key('adm_review_back'),
              onPressed: () => setState(() => _step = 1),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
            LoadingButton(
              key: const Key('adm_confirm'),
              label: 'Confirm admission',
              icon: Icons.check,
              isLoading: _saving,
              onPressed: _confirm,
            ),
          ],
        ),
      ],
    );
  }

  Widget _reviewRow(ThemeData theme, String label, List<String> values) {
    final text = values.where((v) => v.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _isoDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime? _parseIsoDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }
}
