import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:school_office_management/shared/extensions/string_extensions.dart';

import '../entities/report_result.dart';

typedef ReportExportSaveFile = Future<String?> Function({
  required String fileName,
  required Uint8List bytes,
  String? dialogTitle,
  String? extension,
});

class ReportExportService {
  ReportExportService({
    ReportExportSaveFile? saveFile,
  }) : _saveFile = saveFile ?? _defaultSaveFile;

  final ReportExportSaveFile _saveFile;

  static Future<String?> _defaultSaveFile({
    required String fileName,
    required Uint8List bytes,
    String? dialogTitle,
    String? extension,
  }) async {
    return await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension ?? 'xlsx'],
      bytes: bytes,
    );
  }

  Future<String?> exportReport(ReportResult result, {String schoolName = ''}) async {
    if (result.details == null || result.details!.isEmpty) {
      return null;
    }

    try {
      final workbook = Excel.createExcel();

      _buildSummarySheet(workbook, result, schoolName);
      _buildDetailsSheet(workbook, result);

      final bytes = await workbook.encodeAsync();
      if (bytes == null) return null;

      final suggestedFileName =
          'report_${result.definition.id}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      return _saveFile(
        fileName: suggestedFileName,
        bytes: Uint8List.fromList(bytes),
        dialogTitle: 'Export Report',
        extension: 'xlsx',
      );
    } catch (e) {
      return null;
    }
  }

  static void _buildSummarySheet(
    Excel workbook,
    ReportResult result,
    String schoolName,
  ) {
    final sheet = workbook['SUMMARY'];

    sheet.appendRow([TextCellValue('School Report Summary')]);
    sheet.appendRow([
      TextCellValue('School Name'),
      TextCellValue(schoolName),
    ]);
    sheet.appendRow([TextCellValue(result.definition.title)]);
    sheet.appendRow([
      TextCellValue(result.definition.category.displayName),
    ]);
    sheet.appendRow([TextCellValue('Selected Filters:')]);
    for (final filter in result.filtersApplied) {
      final value = filter.options?.firstOrNull?.label ?? '—';
      sheet.appendRow([TextCellValue('${filter.name}: $value')]);
    }
    sheet.appendRow([
      TextCellValue(
        'Generated at: ${DateFormat.yMMMd().add_jm().format(result.generatedAt)}',
      ),
    ]);
    final recordCount = result.summary?['record_count'] ??
        result.summary?['total'] ??
        0;
    sheet.appendRow([TextCellValue('Record Count: $recordCount')]);
  }

  static void _buildDetailsSheet(Excel workbook, ReportResult result) {
    final sheet = workbook['DETAILS'];

    if (result.details == null || result.details!.isEmpty) return;

    final details = result.details!;
    final firstRow = details.first;

    sheet.appendRow([
      for (final key in firstRow.keys)
        TextCellValue(key.replaceAll('_', ' ').capitalizeFirst()),
    ]);

    for (final row in details) {
      sheet.appendRow([
        for (final key in firstRow.keys) _detailsCell(row[key]),
      ]);
    }
  }

  static CellValue? _detailsCell(dynamic value) {
    if (value == null) return null;
    if (value is num) return DoubleCellValue(value.toDouble());
    if (value is DateTime) return DateCellValue.fromDateTime(value);
    return TextCellValue(value.toString());
  }
}
