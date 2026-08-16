import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/utils/formatters.dart';
import '../../settings/domain/services/settings_service.dart';
import '../application/receipt_printer.dart';
import '../domain/entities/receipt_data.dart';

/// On-screen view of a fee receipt with a "Save PDF" action that routes
/// through [ReceiptPrinter] (injectable for widget tests). When a
/// [settingsService] is supplied the header is branded with the configured
/// school profile (name, address, phone, logo) instead of the generic app
/// name.
class ReceiptScreen extends StatelessWidget {
  ReceiptScreen({
    super.key,
    required this.receipt,
    this.settingsService,
    ReceiptPrinter? printer,
  }) : printer = printer ?? ReceiptPrinter();

  final ReceiptData receipt;
  final SettingsService? settingsService;
  final ReceiptPrinter printer;

  Future<void> _save(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await printer.saveReceiptPdf(
      receipt,
      profile: settingsService?.profile,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Receipt PDF saved.'
                : 'Receipt save cancelled — no file was saved.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = receipt;
    final profile = settingsService?.profile;
    final schoolName = (profile?.schoolName ?? '').trim().isEmpty
        ? AppConfig.appName
        : profile!.schoolName.trim();
    final address = profile?.address.trim() ?? '';
    final phone = profile?.phone.trim() ?? '';
    final footer = profile?.receiptFooter.trim() ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Fee Receipt')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (r.isReversed)
            Container(
              key: const Key('receipt_voided_banner'),
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'VOIDED — this payment was reversed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (settingsService != null &&
                      settingsService!.profile.hasLogo)
                    Center(
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: FutureBuilder(
                          future: settingsService!.getLogoBytes(),
                          builder: (context, snapshot) {
                            final bytes = snapshot.data;
                            if (bytes == null) {
                              return const SizedBox.shrink();
                            }
                            return Image.memory(bytes, fit: BoxFit.contain);
                          },
                        ),
                      ),
                    ),
                  Text(
                    schoolName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      address,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'FEE RECEIPT',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      letterSpacing: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Divider(height: 32),
                  _row(context, 'Receipt number', r.receiptNumber, bold: true),
                  _row(context, 'Payment ID', r.paymentId),
                  _row(context, 'Date', Formatters.date(r.paymentDate)),
                  const Divider(height: 24),
                  _row(context, 'Student', r.studentName, bold: true),
                  _row(context, 'Student ID', r.studentId),
                  if (r.guardianName != null)
                    _row(context, 'Guardian', r.guardianName!),
                  _row(context, 'Fee period', r.periodLabel),
                  const Divider(height: 24),
                  _row(
                    context,
                    'Expected amount',
                    Formatters.money(r.expectedAmount),
                  ),
                  _row(context, 'Discount', Formatters.money(r.discount)),
                  _row(context, 'Fine', Formatters.money(r.fine)),
                  _row(
                    context,
                    'Net payable',
                    Formatters.money(r.netPayable),
                  ),
                  _row(context, 'Amount paid', Formatters.money(r.paidAmount)),
                  _row(
                    context,
                    'Remaining',
                    Formatters.money(r.remainingAmount),
                  ),
                  const Divider(height: 24),
                  if (r.paymentNote != null && r.paymentNote!.isNotEmpty)
                    _row(context, 'Note', r.paymentNote!),
                  if (r.createdByName != null && r.createdByName!.isNotEmpty)
                    _row(context, 'Received by', r.createdByName!),
                  if (footer.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text(
                      footer,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('receipt_save_pdf'),
            onPressed: () => _save(context),
            icon: const Icon(Icons.save_alt_rounded),
            label: const Text('Save PDF'),
          ),
          const SizedBox(height: 8),
          Text(
            'Open the saved PDF to print it.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false}) {
    final theme = Theme.of(context);
    final style = bold
        ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }
}
