import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/utils/formatters.dart';
import '../../settings/domain/entities/school_profile.dart';
import '../domain/entities/receipt_data.dart';
import 'simple_pdf_writer.dart';

/// Builds and saves the printable fee receipt.
///
/// The receipt PDF is produced by the pure-Dart [SimplePdfWriter] (no native
/// plugin) and saved through the platform file dialog (Windows save dialog /
/// web download). The user can then print the PDF from their viewer.
class ReceiptPrinter {
  /// The save action is injectable so widget tests never touch the file dialog.
  ReceiptPrinter({
    Future<bool> Function(Uint8List bytes, String fileName)? saver,
  }) : _saver = saver ?? _saveWithFilePicker;

  final Future<bool> Function(Uint8List bytes, String fileName) _saver;

  static Future<bool> _saveWithFilePicker(
    Uint8List bytes,
    String fileName,
  ) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save fee receipt',
      fileName: fileName,
      type: FileType.any,
      bytes: bytes,
    );
    return path != null;
  }

  /// Saves the receipt as a PDF. Returns true when the user chose a location.
  Future<bool> saveReceiptPdf(ReceiptData data, {SchoolProfile? profile}) {
    final bytes = buildReceiptPdf(data, profile: profile);
    return _saver(bytes, 'Receipt-${_safeName(data.receiptNumber)}.pdf');
  }

  /// Renders the receipt to PDF bytes (pure function — easy to unit test).
  Uint8List buildReceiptPdf(ReceiptData data, {SchoolProfile? profile}) {
    final schoolName = (profile?.schoolName ?? '').trim().isEmpty
        ? AppConfig.appName
        : profile!.schoolName.trim();
    final pdf = SimplePdfWriter();
    pdf.text(schoolName, size: 18, bold: true);
    if ((profile?.address ?? '').trim().isNotEmpty) {
      pdf.text(profile!.address.trim(), size: 9);
    }
    if ((profile?.phone ?? '').trim().isNotEmpty) {
      pdf.text(profile!.phone.trim(), size: 9);
    }
    pdf.spacer(2);
    pdf.text('FEE RECEIPT', size: 14, bold: true);
    pdf.spacer(6);
    pdf.rule();
    pdf.text('Receipt number: ${data.receiptNumber}',
        size: 11, bold: true);
    pdf.text('Payment ID: ${data.paymentId}', size: 10);
    pdf.text('Date: ${Formatters.date(data.paymentDate)}', size: 10);
    pdf.rule();
    pdf.text('Student: ${data.studentName}', bold: true);
    pdf.text('Student ID: ${data.studentId}', size: 10);
    pdf.text(
      'Guardian: ${data.guardianName ?? '—'}',
      size: 10,
    );
    pdf.text('Fee period: ${data.periodLabel}', size: 10);
    pdf.rule();
    pdf.text('Expected amount', indent: 0, size: 11);
    pdf.text(Formatters.money(data.expectedAmount), indent: 260, size: 11);
    pdf.text('Discount', size: 11);
    pdf.text(Formatters.money(data.discount), indent: 260, size: 11);
    pdf.text('Fine', size: 11);
    pdf.text(Formatters.money(data.fine), indent: 260, size: 11);
    pdf.text('Net payable', size: 11);
    pdf.text(Formatters.money(data.netPayable), indent: 260, size: 11);
    pdf.text('Amount paid', size: 11);
    pdf.text(Formatters.money(data.paidAmount), indent: 260, size: 11);
    pdf.text('Remaining', size: 11);
    pdf.text(Formatters.money(data.remainingAmount), indent: 260, size: 11);
    pdf.rule();
    if (data.paymentNote != null && data.paymentNote!.isNotEmpty) {
      pdf.text('Note: ${data.paymentNote}', size: 10);
    }
    if (data.createdByName != null && data.createdByName!.isNotEmpty) {
      pdf.text('Received by: ${data.createdByName}', size: 10);
    }
    if (data.isReversed) {
      pdf.spacer(8);
      pdf.text('VOIDED - THIS PAYMENT WAS REVERSED', size: 13, bold: true);
    }
    pdf.spacer(12);
    final footer = (profile?.receiptFooter ?? '').trim();
    pdf.text(
      footer.isEmpty ? 'This is a computer-generated receipt.' : footer,
      size: 9,
    );
    return pdf.build();
  }

  static String _safeName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'receipt' : cleaned;
  }
}
