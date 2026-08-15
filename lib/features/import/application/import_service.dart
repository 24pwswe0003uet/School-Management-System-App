import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../domain/entities/column_mapping.dart';
import '../domain/entities/custom_field.dart';
import '../domain/entities/import_plan.dart';
import '../domain/entities/import_result.dart';
import '../domain/entities/import_workbook.dart';
import '../domain/repositories/import_repository.dart';
import '../domain/services/column_mapper.dart';
import '../domain/services/excel_reader.dart';
import '../domain/services/export_service.dart';
import '../domain/services/import_planner.dart';

/// Where the operator is in the import flow.
enum ImportStep {
  /// Choosing the file to import.
  pickFile,

  /// Choosing which worksheet to use.
  pickSheet,

  /// Confirming/editing the automatic column mapping.
  mapColumns,

  /// Reviewing the plan (what will be imported vs. skipped) before running.
  preview,

  /// The import finished; show the result screen.
  result,
}

/// Drives the whole import flow: pick -> sheet -> mapping -> plan -> run.
/// The UI renders one step at a time and calls back into this service.
class ImportService extends ChangeNotifier {
  ImportService({
    required ExcelReader reader,
    required ColumnMapper mapper,
    required ImportPlanner planner,
    required ImportRepository repository,
    required ExportService exportService,
  }) : _reader = reader,
       _mapper = mapper,
       _planner = planner,
       _repository = repository,
       _exportService = exportService;

  final ExcelReader _reader;
  final ColumnMapper _mapper;
  final ImportPlanner _planner;
  final ImportRepository _repository;
  final ExportService _exportService;

  ImportStep step = ImportStep.pickFile;
  bool busy = false;
  String? errorMessage;

  String? fileName;
  List<String> sheetNames = const [];
  String? selectedSheetName;
  ImportSheetData? sheetData;
  List<ColumnMapping> columns = const [];
  List<CustomFieldDefinition> customFields = const [];
  ImportPlan? plan;
  ImportResult? result;

  bool running = false;
  int processed = 0;
  int total = 0;
  bool includePossibleDuplicates = false;

  bool get hasPlan => plan != null;

  /// Picks an `.xlsx`/`.xls` file and loads its worksheets.
  Future<void> pickFile() async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'Choose an Excel file to import',
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        busy = false;
        notifyListeners();
        return;
      }
      final file = picked.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw const ImportFileException(
          'The file could not be read from the picker.',
        );
      }
      final workbook = await _reader.load(bytes, fileName: file.name);
      fileName = workbook.fileName;
      sheetNames = workbook.sheetNames;
      _resetWorkbookState();
      step = ImportStep.pickSheet;
    } on ImportFileException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'The file dialog could not be opened.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Loads one worksheet and auto-maps its columns.
  Future<void> selectSheet(String name) async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final data = _reader.readSheet(name);
      sheetData = data;
      selectedSheetName = name;
      customFields = await _repository.listCustomFields();
      columns = _mapper.mapColumns(data.headers, customFields: customFields);
      plan = null;
      result = null;
      step = ImportStep.mapColumns;
    } on ImportFileException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'The worksheet could not be read.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Replaces the mapping for one column (e.g. the user retargeted it).
  void setColumnMapping(int index, ColumnMapping mapping) {
    final next = [...columns];
    next[index] = mapping;
    columns = next;
    plan = null;
    notifyListeners();
  }

  /// Whether possible duplicates should be imported too.
  void setIncludePossibleDuplicates(bool value) {
    if (includePossibleDuplicates == value) return;
    includePossibleDuplicates = value;
    notifyListeners();
  }

  /// Backs up to a previous step, clearing anything built later.
  void goTo(ImportStep target) {
    if (target.index < step.index) {
      switch (target) {
        case ImportStep.pickFile:
          _resetWorkbookState();
        case ImportStep.pickSheet:
          sheetData = null;
          selectedSheetName = null;
          columns = const [];
          plan = null;
        case ImportStep.mapColumns:
          plan = null;
        case ImportStep.preview:
        case ImportStep.result:
          break;
      }
    }
    errorMessage = null;
    step = target;
    notifyListeners();
  }

  /// Builds the validated import plan (family grouping + duplicate
  /// classification). Called when the operator opens the preview step.
  Future<void> buildPlan() async {
    final data = sheetData;
    if (data == null || columns.isEmpty) return;
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      plan = await _planner.buildPlan(
        sheetName: data.name,
        columns: columns,
        sheetRows: data.rows,
        repository: _repository,
      );
      step = ImportStep.preview;
    } catch (_) {
      errorMessage = 'The import plan could not be prepared.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Runs the import. Progress updates are surfaced through [processed]/
  /// [total] and [running].
  Future<void> startImport() async {
    final currentPlan = plan;
    if (currentPlan == null) return;
    running = true;
    processed = 0;
    total = currentPlan.totalRows;
    errorMessage = null;
    notifyListeners();
    try {
      result = await _repository.importPlan(
        currentPlan,
        includePossibleDuplicates: includePossibleDuplicates,
        onProgress: (p, t) {
          processed = p;
          total = t;
          notifyListeners();
        },
      );
      step = ImportStep.result;
    } catch (_) {
      errorMessage =
          'The import failed and was rolled back. Nothing was changed.';
    } finally {
      running = false;
      notifyListeners();
    }
  }

  /// Exports the current plan's error report (all skipped rows) as CSV.
  Future<void> exportReport() async {
    final currentPlan = plan;
    if (currentPlan == null) return;
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _exportService.exportErrorReport(currentPlan);
    } catch (_) {
      errorMessage = 'The error report could not be exported.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Exports all students to an `.xlsx` file. Returns true when the file was
  /// saved, false when cancelled or when there is nothing to export.
  Future<bool> exportStudents() async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final saved = await _exportService.exportStudents();
      return saved != null;
    } catch (_) {
      errorMessage = 'The export could not be saved.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Starts over at the file-pick step.
  void reset() {
    _resetWorkbookState();
    errorMessage = null;
    result = null;
    running = false;
    step = ImportStep.pickFile;
    notifyListeners();
  }

  void _resetWorkbookState() {
    selectedSheetName = null;
    sheetData = null;
    columns = const [];
    customFields = const [];
    plan = null;
    result = null;
    includePossibleDuplicates = false;
  }
}
