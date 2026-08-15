import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';

import '../entities/import_workbook.dart';

/// Thrown when a workbook/sheet cannot be read. Messages are user-friendly
/// and never expose internals.
class ImportFileException implements Exception {
  const ImportFileException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Thin wrapper over excel_plus. Decoding runs on a background isolate; on
/// the web it falls back to the main thread transparently.
class ExcelReader {
  Excel? _workbook;

  /// Hook for tests: subclasses can decode synchronously to avoid real
  /// isolates under the widget-test fake-async zone.
  Future<Excel> decodeBytes(List<int> bytes) => Excel.decodeBytesAsync(bytes);

  Future<LoadedWorkbook> load(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final Excel excel;
    try {
      excel = await decodeBytes(bytes);
    } on ExcelException catch (e) {
      throw ImportFileException(
        'The file could not be opened as an Excel workbook.',
        e,
      );
    } catch (e) {
      throw ImportFileException(
        'The file could not be read. Please choose a valid .xlsx or .xls file.',
        e,
      );
    }
    _workbook = excel;
    final names = excel.sheetOrder;
    if (names.isEmpty) {
      throw const ImportFileException('This workbook has no worksheets.');
    }
    return LoadedWorkbook(fileName: fileName, sheetNames: names);
  }

  Excel get workbook {
    final workbook = _workbook;
    if (workbook == null) {
      throw const ImportFileException('No workbook is loaded.');
    }
    return workbook;
  }

  /// Reads [sheetName] into plain values. The first row with any content is
  /// treated as the header row. Throws [ImportFileException] on empty sheets,
  /// missing/duplicate headers, etc.
  ImportSheetData readSheet(String sheetName) {
    final excel = workbook;
    if (!excel.tables.containsKey(sheetName)) {
      throw ImportFileException('Worksheet "$sheetName" was not found.');
    }
    final sheet = excel[sheetName];

    final grid = <List<Object?>>[];
    for (var r = 0; r < sheet.maxRows; r++) {
      grid.add(sheet.rows[r].map(_cellToPlain).toList());
    }
    while (grid.isNotEmpty && grid.last.every(_isEmpty)) {
      grid.removeLast();
    }
    if (grid.isEmpty) {
      throw ImportFileException('The worksheet "$sheetName" is empty.');
    }

    var headerIndex = -1;
    for (var i = 0; i < grid.length; i++) {
      if (grid[i].any((cell) => !_isEmpty(cell))) {
        headerIndex = i;
        break;
      }
    }
    if (headerIndex == -1) {
      throw ImportFileException('The worksheet "$sheetName" is empty.');
    }

    var headers = grid[headerIndex]
        .map((h) => h?.toString().trim() ?? '')
        .toList();
    while (headers.isNotEmpty && headers.last.isEmpty) {
      headers.removeLast();
    }
    if (headers.isEmpty) {
      throw ImportFileException(
        'No column headers were found in "$sheetName".',
      );
    }

    final seen = <String>{};
    final duplicates = <String>{};
    for (final header in headers) {
      if (header.isEmpty) continue;
      if (!seen.add(header)) duplicates.add(header);
    }
    if (duplicates.isNotEmpty) {
      throw ImportFileException(
        'Duplicate column headers found: ${duplicates.join(', ')}.',
      );
    }

    final width = headers.length;
    final rows = <List<Object?>>[];
    for (var i = headerIndex + 1; i < grid.length; i++) {
      final source = grid[i];
      final padded = List<Object?>.filled(width, null);
      final count = source.length < width ? source.length : width;
      for (var c = 0; c < count; c++) {
        padded[c] = source[c];
      }
      if (padded.every(_isEmpty)) continue;
      rows.add(padded);
    }
    return ImportSheetData(name: sheetName, headers: headers, rows: rows);
  }

  static Object? _cellToPlain(Data? data) {
    if (data == null) return null;
    final value = data.value;
    if (value == null) return null;
    return switch (value) {
      IntCellValue() => value.value,
      DoubleCellValue() => value.value,
      BoolCellValue() => value.value,
      DateCellValue() => value.asDateTimeLocal(),
      DateTimeCellValue() => value.asDateTimeLocal(),
      TextCellValue() => value.value.text,
      FormulaCellValue() => value.cachedValue,
      CellErrorValue() => null,
      _ => value.toString(),
    };
  }

  static bool _isEmpty(Object? value) {
    if (value == null) return true;
    return value.toString().trim().isEmpty;
  }
}
