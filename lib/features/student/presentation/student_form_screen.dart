import 'package:flutter/material.dart';

import '../../../shared/widgets/loading_button.dart';
import '../../family/domain/entities/family.dart';
import '../../family/domain/entities/family_list_item.dart';
import '../../family/domain/services/family_service.dart';
import '../../family/presentation/family_form_screen.dart';
import '../domain/entities/student.dart';
import '../domain/entities/student_list_item.dart';
import '../domain/services/student_service.dart';
import 'student_details_screen.dart';

/// Create / edit a student. A family must be selected; if no family exists the
/// operator can create one and the form returns to it automatically. On create
/// the generated Student ID is shown read-only and possible duplicates are
/// surfaced before saving.
class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({
    super.key,
    required this.studentService,
    required this.familyService,
    this.existing,
    this.preselectedFamilyId,
  });

  final StudentService studentService;
  final FamilyService familyService;
  final Student? existing;

  /// When opened from a family profile, the form starts with this family
  /// already selected.
  final int? preselectedFamilyId;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

sealed class _DupDecision {
  const _DupDecision();
}

class _DupCreate extends _DupDecision {
  const _DupCreate();
}

class _DupInspect extends _DupDecision {
  const _DupInspect(this.student);
  final Student student;
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _dob;
  late final TextEditingController _admissionNumber;
  late final TextEditingController _admissionDate;
  late final TextEditingController _class;
  late final TextEditingController _section;
  late final TextEditingController _contactReference;
  late final TextEditingController _notes;

  StudentGender? _gender;
  Family? _family;
  String? _studentId;
  bool _submitting = false;
  String? _familyError;

  bool _pickingFamily = false;
  List<FamilyListItem> _familyResults = const [];
  bool _familyLoading = false;
  String _familyQuery = '';

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _dob = TextEditingController(
      text: existing?.dateOfBirth == null
          ? ''
          : _isoDate(existing!.dateOfBirth!),
    );
    _admissionNumber = TextEditingController(
      text: existing?.admissionNumber ?? '',
    );
    _admissionDate = TextEditingController(
      text: existing?.admissionDate == null
          ? ''
          : _isoDate(existing!.admissionDate!),
    );
    _class = TextEditingController(text: existing?.className ?? '');
    _section = TextEditingController(text: existing?.section ?? '');
    _contactReference = TextEditingController(
      text: existing?.contactReference ?? '',
    );
    _notes = TextEditingController(text: existing?.notes ?? '');
    _gender = existing?.gender;
    if (existing != null) {
      _studentId = existing.studentId;
      _loadFamily(existing.familyId);
    } else if (widget.preselectedFamilyId != null) {
      widget.studentService.nextStudentId().then((id) {
        if (mounted) setState(() => _studentId = id);
      });
      _loadFamily(widget.preselectedFamilyId!);
    } else {
      widget.studentService.nextStudentId().then((id) {
        if (mounted) setState(() => _studentId = id);
      });
      _pickingFamily = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFamilies('');
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dob.dispose();
    _admissionNumber.dispose();
    _admissionDate.dispose();
    _class.dispose();
    _section.dispose();
    _contactReference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadFamily(int familyId) async {
    try {
      final details = await widget.familyService.getFamilyDetails(familyId);
      if (mounted) setState(() => _family = details.family);
    } catch (_) {
      if (mounted) {
        setState(() => _familyError = 'The family could not be loaded.');
      }
    }
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_family == null) {
      setState(
        () => _familyError = 'A family must be selected for the student.',
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final service = widget.studentService;
      final existing = widget.existing;
      final name = _name.text;
      final admissionNumber = _admissionNumber.text;
      final dob = _parseIsoDate(_dob.text);
      final admissionDate = _parseIsoDate(_admissionDate.text);
      final family = _family!;

      if (!_isEdit) {
        final duplicates = await service.findPossibleStudentDuplicates(
          name: name,
          admissionNumber: admissionNumber,
          familyId: family.id,
          guardianName: family.guardianName,
          primaryPhone: family.primaryPhone,
        );
        if (duplicates.isNotEmpty) {
          final decision = await _showDuplicateDialog(duplicates);
          if (!mounted) return;
          if (decision == null) {
            setState(() => _submitting = false);
            return;
          }
          if (decision is _DupInspect) {
            setState(() => _submitting = false);
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StudentDetailsScreen(
                  studentService: service,
                  familyService: widget.familyService,
                  studentId: decision.student.id,
                ),
              ),
            );
            return;
          }
        }
        final created = await service.createStudent(
          familyId: family.id,
          name: name,
          gender: _gender,
          dateOfBirth: dob,
          admissionNumber: admissionNumber,
          admissionDate: admissionDate,
          className: _class.text,
          section: _section.text,
          contactReference: _contactReference.text,
          notes: _notes.text,
        );
        if (!mounted) return;
        Navigator.of(context).pop(created);
      } else {
        final updated = await service.updateStudent(
          id: existing!.id,
          familyId: family.id,
          name: name,
          gender: _gender,
          dateOfBirth: dob,
          admissionNumber: admissionNumber,
          admissionDate: admissionDate,
          className: _class.text,
          section: _section.text,
          contactReference: _contactReference.text,
          notes: _notes.text,
        );
        if (!mounted) return;
        Navigator.of(context).pop(updated);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not save the student. Please try again.'),
          ),
        );
    }
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
                  'Similar student records were found. Review them before '
                  'saving to avoid duplicates.',
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
                        key: ValueKey('stu_dup_${s.studentId}'),
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
              key: const Key('stu_dup_cancel'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('stu_dup_save_anyway'),
              onPressed: () => Navigator.of(context).pop(const _DupCreate()),
              child: const Text('Save anyway'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Student' : 'Add Student')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      _buildFamilySection(theme),
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const Key('student_name'),
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
                        key: const Key('student_gender'),
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
                              key: const Key('student_dob'),
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
                              key: const Key('student_admission_date'),
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
                            child: TextFormField(
                              key: const Key('student_class'),
                              controller: _class,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Class',
                                hintText: 'e.g. Class 5',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              key: const Key('student_section'),
                              controller: _section,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Section',
                                hintText: 'e.g. A',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('student_admission_number'),
                        controller: _admissionNumber,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Admission number (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('student_contact_reference'),
                        controller: _contactReference,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Contact / reference (optional)',
                          hintText: 'e.g. emergency contact',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('student_notes'),
                        controller: _notes,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: LoadingButton(
                          key: const Key('student_save'),
                          label: _isEdit ? 'Save changes' : 'Register student',
                          icon: _isEdit ? Icons.save : Icons.person_add_rounded,
                          isLoading: _submitting,
                          onPressed: _submit,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFamilySection(ThemeData theme) {
    if (_family != null && !_pickingFamily) {
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
                key: const Key('student_change_family'),
                onPressed: () {
                  setState(() {
                    _pickingFamily = true;
                    _familyResults = const [];
                  });
                  _searchFamilies('');
                },
                child: const Text('Change'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Family *', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        TextField(
          key: const Key('student_family_picker_search'),
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
                      'family_pick_${_familyResults[i].family.familyId}',
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
          key: const Key('student_create_family'),
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
