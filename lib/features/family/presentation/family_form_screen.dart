import 'package:flutter/material.dart';

import '../../../shared/widgets/loading_button.dart';
import '../../settings/domain/services/settings_service.dart';
import '../../student/domain/services/student_service.dart';
import '../domain/entities/family.dart';
import '../domain/services/family_service.dart';
import 'family_details_screen.dart';

/// Create / edit a family. On create the generated family ID is shown
/// read-only, and possible duplicates are surfaced before saving.
class FamilyFormScreen extends StatefulWidget {
  const FamilyFormScreen({
    super.key,
    required this.familyService,
    required this.studentService,
    required this.settingsService,
    this.existing,
  });

  final FamilyService familyService;
  final StudentService studentService;
  final SettingsService settingsService;
  final Family? existing;

  @override
  State<FamilyFormScreen> createState() => _FamilyFormScreenState();
}

sealed class _DupDecision {
  const _DupDecision();
}

class _DupCreate extends _DupDecision {
  const _DupCreate();
}

class _DupInspect extends _DupDecision {
  const _DupInspect(this.family);
  final Family family;
}

class _FamilyFormScreenState extends State<FamilyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _guardian;
  late final TextEditingController _mother;
  late final TextEditingController _phone;
  late final TextEditingController _secondaryPhone;
  late final TextEditingController _address;
  late final TextEditingController _cnic;
  late final TextEditingController _notes;

  bool _submitting = false;
  String? _familyId;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _guardian = TextEditingController(text: existing?.guardianName ?? '');
    _mother = TextEditingController(text: existing?.motherName ?? '');
    _phone = TextEditingController(text: existing?.primaryPhone ?? '');
    _secondaryPhone = TextEditingController(
      text: existing?.secondaryPhone ?? '',
    );
    _address = TextEditingController(text: existing?.address ?? '');
    _cnic = TextEditingController(text: existing?.cnic ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    if (existing != null) {
      _familyId = existing.familyId;
    } else {
      widget.familyService.nextFamilyId().then((id) {
        if (mounted) setState(() => _familyId = id);
      });
    }
  }

  @override
  void dispose() {
    _guardian.dispose();
    _mother.dispose();
    _phone.dispose();
    _secondaryPhone.dispose();
    _address.dispose();
    _cnic.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _validateGuardian(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the father/guardian name.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^[0-9+\- ]+$').hasMatch(trimmed)) {
      return 'Phone can only contain digits, spaces, + or -.';
    }
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  String? _validateCnic(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 13) {
      return 'CNIC must be exactly 13 digits.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final service = widget.familyService;
      final existing = widget.existing;
      final guardian = _guardian.text;
      final mother = _mother.text;
      final phone = _phone.text;
      final secondary = _secondaryPhone.text;
      final address = _address.text;
      final cnic = _cnic.text;
      final notes = _notes.text;

      if (!_isEdit) {
        final duplicates = await service.findPossibleDuplicates(
          guardianName: guardian,
          motherName: mother,
          primaryPhone: phone,
          secondaryPhone: secondary,
          address: address,
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
                builder: (_) => FamilyDetailsScreen(
                  familyService: service,
                  studentService: widget.studentService,
                  settingsService: widget.settingsService,
                  familyId: decision.family.id,
                ),
              ),
            );
            return;
          }
        }
        final created = await service.createFamily(
          guardianName: guardian,
          motherName: mother,
          primaryPhone: phone,
          secondaryPhone: secondary,
          address: address,
          cnic: cnic,
          notes: notes,
        );
        if (!mounted) return;
        Navigator.of(context).pop(created);
      } else {
        final updated = await service.updateFamily(
          id: existing!.id,
          guardianName: guardian,
          motherName: mother,
          primaryPhone: phone,
          secondaryPhone: secondary,
          address: address,
          cnic: cnic,
          notes: notes,
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
            content: Text('Could not save the family. Please try again.'),
          ),
        );
    }
  }

  Future<_DupDecision?> _showDuplicateDialog(List<Family> duplicates) {
    return showDialog<_DupDecision>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Possible existing families'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Similar families were found. Review them before saving to '
                  'avoid duplicate records.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    itemCount: duplicates.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final family = duplicates[index];
                      return ListTile(
                        key: ValueKey('dup_${family.familyId}'),
                        dense: true,
                        leading: const Icon(Icons.family_restroom),
                        title: Text(family.guardianName),
                        subtitle: Text(
                          [
                            family.familyId,
                            if (family.primaryPhone != null &&
                                family.primaryPhone!.isNotEmpty)
                              family.primaryPhone!,
                          ].join(' · '),
                        ),
                        trailing: const Text('View'),
                        onTap: () =>
                            Navigator.of(context).pop(_DupInspect(family)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('dup_cancel'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('dup_create_anyway'),
              onPressed: () => Navigator.of(context).pop(const _DupCreate()),
              child: const Text('Create anyway'),
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
      appBar: AppBar(title: Text(_isEdit ? 'Edit Family' : 'Add Family')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_familyId != null) ...[
                        Text('Family ID', style: theme.textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Text(
                          _familyId!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      TextFormField(
                        key: const Key('family_guardian'),
                        controller: _guardian,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Father / Guardian name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateGuardian,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('family_mother'),
                        controller: _mother,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Mother name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('family_phone'),
                              controller: _phone,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Primary phone',
                                hintText: '0300-1234567',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validatePhone,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              key: const Key('family_secondary_phone'),
                              controller: _secondaryPhone,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Secondary phone',
                                border: OutlineInputBorder(),
                              ),
                              validator: _validatePhone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('family_address'),
                        controller: _address,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('family_cnic'),
                        controller: _cnic,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'CNIC (optional)',
                          hintText: 'XXXXX-XXXXXXX-X',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateCnic,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('family_notes'),
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
                          key: const Key('family_save'),
                          label: _isEdit ? 'Save changes' : 'Create family',
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
}
