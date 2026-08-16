import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/repositories/settings_repository.dart';
import '../../domain/services/settings_service.dart';

/// Profile tab: school identity, contact details, academic year and logo.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _schoolName;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _academicYear;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _schoolName = TextEditingController(text: widget.settingsService.profile.schoolName);
    _address = TextEditingController(text: widget.settingsService.profile.address);
    _phone = TextEditingController(text: widget.settingsService.profile.phone);
    _email = TextEditingController(text: widget.settingsService.profile.email);
    _academicYear = TextEditingController(
      text: widget.settingsService.profile.academicYear,
    );
  }

  @override
  void dispose() {
    _schoolName.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _academicYear.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.settingsService.saveProfile(
        schoolName: _schoolName.text,
        address: _address.text,
        phone: _phone.text,
        email: _email.text,
        academicYear: _academicYear.text,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile saved.')),
      );
    } on SettingsValidationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickLogo() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final name = file.name.toLowerCase();
    final Uint8List? bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not read the selected file.')),
      );
      return;
    }
    final String mimeType;
    if (name.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      mimeType = 'image/jpeg';
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please choose a PNG or JPEG image.'),
        ),
      );
      return;
    }
    try {
      await widget.settingsService.updateLogo(bytes: bytes, mimeType: mimeType);
      messenger.showSnackBar(
        const SnackBar(content: Text('Logo updated.')),
      );
    } on SettingsValidationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _removeLogo() async {
    await widget.settingsService.removeLogo();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo removed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.settingsService;
    final canEdit = service.isAdmin;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LogoSection(
                  settingsService: service,
                  canEdit: canEdit,
                  onPickLogo: _pickLogo,
                  onRemoveLogo: _removeLogo,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('settings_school_name'),
                  controller: _schoolName,
                  enabled: canEdit,
                  decoration: const InputDecoration(
                    labelText: 'School name',
                    hintText: 'e.g. Bright Future School',
                    border: OutlineInputBorder(),
                  ),
                  validator: SettingsService.validateSchoolName,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('settings_address'),
                  controller: _address,
                  enabled: canEdit,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('settings_phone'),
                        controller: _phone,
                        enabled: canEdit,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          border: OutlineInputBorder(),
                        ),
                        validator: SettingsService.validatePhone,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        key: const Key('settings_email'),
                        controller: _email,
                        enabled: canEdit,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: SettingsService.validateEmail,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('settings_academic_year'),
                  controller: _academicYear,
                  enabled: canEdit,
                  decoration: const InputDecoration(
                    labelText: 'Academic year',
                    hintText: 'e.g. 2025–2026',
                    border: OutlineInputBorder(),
                  ),
                  validator: SettingsService.validateAcademicYear,
                ),
                if (canEdit) ...[
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      key: const Key('settings_save_profile'),
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save profile'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  const _LogoSection({
    required this.settingsService,
    required this.canEdit,
    required this.onPickLogo,
    required this.onRemoveLogo,
  });

  final SettingsService settingsService;
  final bool canEdit;
  final Future<void> Function() onPickLogo;
  final Future<void> Function() onRemoveLogo;

  @override
  Widget build(BuildContext context) {
    final hasLogo = settingsService.profile.hasLogo;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 96,
            height: 96,
            child: hasLogo
                ? FutureBuilder(
                    future: settingsService.getLogoBytes(),
                    builder: (context, snapshot) {
                      final bytes = snapshot.data;
                      if (bytes == null) {
                        return const _LogoPlaceholder();
                      }
                      return Image.memory(bytes, fit: BoxFit.contain);
                    },
                  )
                : const _LogoPlaceholder(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasLogo ? 'School logo' : 'No logo set',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'A PNG or JPEG image up to 1 MB. It appears on receipts and '
                'the profile header.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (canEdit) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      key: const Key('settings_change_logo'),
                      onPressed: onPickLogo,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Change logo'),
                    ),
                    if (hasLogo) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        key: const Key('settings_remove_logo'),
                        tooltip: 'Remove logo',
                        onPressed: onRemoveLogo,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.school_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
