import 'package:flutter/material.dart';

import '../../domain/repositories/settings_repository.dart';
import '../../domain/services/settings_service.dart';

/// Receipt tab: the footer line printed under every fee receipt.
class ReceiptTab extends StatefulWidget {
  const ReceiptTab({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  State<ReceiptTab> createState() => _ReceiptTabState();
}

class _ReceiptTabState extends State<ReceiptTab> {
  late final TextEditingController _footer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _footer = TextEditingController(
      text: widget.settingsService.profile.receiptFooter,
    );
  }

  @override
  void dispose() {
    _footer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.settingsService.saveProfile(
        schoolName: widget.settingsService.profile.schoolName,
        address: widget.settingsService.profile.address,
        phone: widget.settingsService.profile.phone,
        email: widget.settingsService.profile.email,
        academicYear: widget.settingsService.profile.academicYear,
        receiptFooter: _footer.text,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Receipt footer saved.')),
      );
    } on SettingsValidationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.settingsService.isAdmin;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Receipt footer',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'The line printed under every fee receipt, e.g. a bank '
                'account number or a thanks note. Leave blank to print '
                'nothing extra.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('settings_receipt_footer'),
                controller: _footer,
                enabled: canEdit,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  hintText: 'e.g. Account: 0001-2345 · Thank you!',
                  border: OutlineInputBorder(),
                ),
              ),
              if (canEdit) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    key: const Key('settings_save_receipt_footer'),
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save footer'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
