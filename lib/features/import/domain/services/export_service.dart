import 'dart:convert';
import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../entities/custom_field.dart';
import '../entities/import_plan.dart';
import '../entities/import_row.dart';
import '../repositories/import_repository.dart';

/// Writes a file via the platform save dialog (default) or a test seam.
typedef ExportSaveFile =
    Future<String?> Function({
      required String fileName,
      required Uint8List bytes,
      String? dialogTitle,
      String? extension,
    });

/// Turns database records back into Excel workbooks / CSV reports.
///
/// Export headers are chosen to be re-importable (the import mapper
/// recognises them), so export -> import round-trips cleanly.
class ExportService {
  ExportService(this._repository, {ExportSaveFile? saveFile})
    : _saveFile = saveFile ?? _defaultSaveFile;

  final ImportRepository _repository;
  final ExportSaveFile _saveFile;

  static Future<String?> _defaultSaveFile({
    required String fileName,
    required Uint8List bytes,
    String? dialogTitle,
    String? extension,
  }) {
    return FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension ?? 'xlsx'],
      bytes: bytes,
    );
  }

  /// Exports all students (with family details and active custom fields) to an
  /// `.xlsx` file via a save dialog. Returns the saved path, or null when the
  /// operator cancels or there is nothing to export.
  Future<String?> exportStudents({String? suggestedFileName}) async {
    final rows = await _repository.exportRows();
    if (rows.isEmpty) return null;

    final studentDefs = await _repository.listCustomFields(
      entityType: 'student',
    );
    final familyDefs = await _repository.listCustomFields(entityType: 'family');
    final studentValues = await _repository.allCustomFieldValuesFor(
      entityType: 'student',
      entityIds: rows.map((r) => r.id).toSet().toList(),
    );
    final familyValues = await _repository.allCustomFieldValuesFor(
      entityType: 'family',
      entityIds: rows.map((r) => r.familyId).toSet().toList(),
    );

    final workbook = Excel.createExcel();
    final sheet = workbook['Students'];
    sheet.appendRow([
      for (final header in _headers(familyDefs, studentDefs))
        TextCellValue(header),
    ]);
    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(row.studentId),
        TextCellValue(row.name),
        _textCell(row.gender),
        _dateCell(row.dateOfBirth),
        _textCell(row.className),
        _textCell(row.section),
        _textCell(row.admissionNumber),
        _dateCell(row.admissionDate),
        row.admissionFee == 0 ? null : DoubleCellValue(row.admissionFee),
        _textCell(row.contactReference),
        _textCell(row.notes),
        _textCell(row.familyIdText),
        _textCell(row.guardianName),
        _textCell(row.motherName),
        _textCell(row.primaryPhone),
        _textCell(row.secondaryPhone),
        _textCell(row.address),
        _textCell(row.cnic),
        for (final def in familyDefs)
          _valueCell(familyValues[def.fieldName]?[row.familyId]),
        for (final def in studentDefs)
          _valueCell(studentValues[def.fieldName]?[row.id]),
      ]);
    }

    final bytes = await workbook.encodeAsync();
    if (bytes == null) return null;
    final fileName = suggestedFileName ?? 'students_export_${_stamp()}.xlsx';
    return _saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      dialogTitle: 'Save student export',
      extension: 'xlsx',
    );
  }

  /// Writes a CSV report of every row that was skipped during an import.
  /// Returns the saved path, or null when cancelled / nothing to report.
  Future<String?> exportErrorReport(ImportPlan plan) async {
    final rows = _reportRows(plan);
    if (rows.isEmpty) return null;

    final workbook = Excel.createExcel();
    final sheet = workbook['ImportErrors'];
    sheet.appendRow([
      TextCellValue('Row'),
      TextCellValue('Student'),
      TextCellValue('Result'),
      TextCellValue('Details'),
    ]);
    for (final r in rows) {
      sheet.appendRow([
        TextCellValue('${r.row}'),
        TextCellValue(r.student),
        TextCellValue(r.result),
        TextCellValue(_csvGuard(r.details)),
      ]);
    }
    final csv = workbook.toCsv(sheet: 'ImportErrors');
    final bytes = Uint8List.fromList(const Utf8Encoder().convert('\uFEFF$csv'));
    final fileName = 'import_errors_${_stamp()}.csv';
    return _saveFile(
      fileName: fileName,
      bytes: bytes,
      dialogTitle: 'Save import report',
      extension: 'csv',
    );
  }

  static List<String> _headers(
    List<CustomFieldDefinition> familyDefs,
    List<CustomFieldDefinition> studentDefs,
  ) {
    return [
      'Student ID',
      'Student Name',
      'Gender',
      'Date of Birth',
      'Class',
      'Section',
      'Admission Number',
      'Admission Date',
      'Admission Fee',
      'Contact Reference',
      'Notes',
      'Family ID',
      'Guardian Name',
      'Mother Name',
      'Primary Phone',
      'Secondary Phone',
      'Address',
      'CNIC',
      for (final def in familyDefs) def.displayName,
      for (final def in studentDefs) def.displayName,
    ];
  }

  static List<_ReportRow> _reportRows(ImportPlan plan) {
    final result = <_ReportRow>[];
    for (final row in plan.rows) {
      switch (row.verdict) {
        case ImportRowVerdict.invalid:
          result.add(
            _ReportRow(
              row.index + 2,
              row.studentName ?? '',
              'Invalid',
              row.errors.map((e) => '${e.field}: ${e.message}').join('; '),
            ),
          );
        case ImportRowVerdict.duplicate:
          result.add(
            _ReportRow(
              row.index + 2,
              row.studentName ?? '',
              'Duplicate',
              row.verdictMessage ?? 'Already exists.',
            ),
          );
        case ImportRowVerdict.possibleDuplicate:
          result.add(
            _ReportRow(
              row.index + 2,
              row.studentName ?? '',
              'Possible duplicate',
              row.verdictMessage ?? 'Review before importing.',
            ),
          );
        case ImportRowVerdict.valid:
          break;
      }
    }
    return result;
  }

  static TextCellValue? _textCell(String? value) =>
      value == null ? null : TextCellValue(value);

  static DateCellValue? _dateCell(DateTime? value) =>
      value == null ? null : DateCellValue.fromDateTime(value);

  static CellValue? _valueCell(String? value) {
    if (value == null || value.isEmpty) return null;
    final text = _csvGuard(value);
    return TextCellValue(text);
  }

  /// Neutralises cells that start with spreadsheet formula markers so opening
  /// the report never triggers formula execution in a spreadsheet program.
  static String _csvGuard(String value) {
    if (value.startsWith('=') ||
        value.startsWith('+') ||
        value.startsWith('-') ||
        value.startsWith('@')) {
      return "'$value";
    }
    return value;
  }

  static String _stamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}

class _ReportRow {
  const _ReportRow(this.row, this.student, this.result, this.details);

  final int row;
  final String student;
  final String result;
  final String details;
}
