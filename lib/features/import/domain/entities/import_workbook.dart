/// Metadata about a loaded workbook (no cell contents — sheets are read on
/// demand once one is selected).
class LoadedWorkbook {
  const LoadedWorkbook({required this.fileName, required this.sheetNames});

  final String fileName;
  final List<String> sheetNames;
}

/// The headers and data rows of one selected sheet, aligned to [headers].
class ImportSheetData {
  const ImportSheetData({
    required this.name,
    required this.headers,
    required this.rows,
  });

  final String name;
  final List<String> headers;
  final List<List<Object?>> rows;
}
