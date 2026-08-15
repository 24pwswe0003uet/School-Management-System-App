import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/import/application/import_service.dart';
import 'package:school_office_management/features/import/domain/entities/import_result.dart';
import 'package:school_office_management/features/import/domain/services/column_mapper.dart';
import 'package:school_office_management/features/import/domain/services/excel_reader.dart';
import 'package:school_office_management/features/import/domain/services/import_planner.dart';
import 'package:school_office_management/features/import/domain/services/export_service.dart';
import 'package:school_office_management/features/import/presentation/import_screen.dart';

import 'fakes/fake_import_repository.dart';

class _FakeFilePicker extends FilePickerPlatform {
  FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    return result;
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    return null;
  }
}

/// Decodes on the main thread so widget tests (fake-async zone) never wait on
/// a real isolate.
class _SyncExcelReader extends ExcelReader {
  @override
  Future<Excel> decodeBytes(List<int> bytes) async => Excel.decodeBytes(bytes);
}

Future<Uint8List> buildWorkbook(
  List<(String, List<List<CellValue?>>)> sheets,
) async {
  final excel = Excel.createExcel();
  if (sheets.isNotEmpty) {
    excel.rename('Sheet1', sheets.first.$1);
    final first = excel[sheets.first.$1];
    for (final row in sheets.first.$2) {
      first.appendRow(row);
    }
  }
  for (final (name, rows) in sheets.skip(1)) {
    final sheet = excel[name];
    for (final row in rows) {
      sheet.appendRow(row);
    }
  }
  return Uint8List.fromList(excel.encode() ?? const []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeFilePicker picker;

  setUp(() {
    picker = _FakeFilePicker();
    FilePickerPlatform.instance = picker;
  });

  Future<ImportService> pumpImportFlow(WidgetTester tester) async {
    final bytes = await buildWorkbook([
      (
        'Students',
        [
          [
            TextCellValue('Student Name'),
            TextCellValue('Admission Number'),
            TextCellValue('Blood Group'),
          ],
          [
            TextCellValue('Ali Khan'),
            TextCellValue('ADM-100'),
            TextCellValue('B+'),
          ],
        ],
      ),
    ]);
    picker.result = FilePickerResult([
      PlatformFile(name: 'students.xlsx', size: bytes.length, bytes: bytes),
    ]);

    final repo = FakeImportRepository()
      ..result = ImportResult(
        importedFamilies: 1,
        importedStudents: 1,
        skippedDuplicates: 0,
        skippedInvalid: 0,
        createdCustomFields: const ['Blood Group'],
        failures: const [],
      );
    final service = ImportService(
      reader: _SyncExcelReader(),
      mapper: ColumnMapper(),
      planner: ImportPlanner(),
      repository: repo,
      exportService: ExportService(repo),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ImportScreen(service: service, onFinished: () {}),
      ),
    );
    return service;
  }

  testWidgets('runs the full pick -> sheet -> map -> preview -> import flow', (
    tester,
  ) async {
    await pumpImportFlow(tester);

    expect(find.text('Import students from Excel'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import_pick_file')));
    await tester.pumpAndSettle();
    expect(find.text('Workbook: students.xlsx'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import_sheet_Students')));
    await tester.pumpAndSettle();
    expect(find.text('Check the column mapping'), findsOneWidget);
    expect(find.textContaining('new custom field'), findsOneWidget);
    expect(find.byKey(const Key('import_map_Blood Group')), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to import'), findsOneWidget);
    expect(find.text('Ali Khan'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import_confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue Import'));
    await tester.pumpAndSettle();

    expect(find.text('Import finished'), findsOneWidget);
    expect(find.text('Students imported'), findsOneWidget);
    expect(find.text('Custom fields: Blood Group'), findsOneWidget);
    expect(find.byKey(const Key('import_done')), findsOneWidget);
  });

  testWidgets('a cancel in the file dialog stays on the pick step', (
    tester,
  ) async {
    picker.result = null;
    final service = ImportService(
      reader: _SyncExcelReader(),
      mapper: ColumnMapper(),
      planner: ImportPlanner(),
      repository: FakeImportRepository(),
      exportService: ExportService(FakeImportRepository()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ImportScreen(service: service, onFinished: () {}),
      ),
    );

    await tester.tap(find.byKey(const Key('import_pick_file')));
    await tester.pumpAndSettle();

    expect(find.text('Import students from Excel'), findsOneWidget);
    expect(service.step, ImportStep.pickFile);
  });

  testWidgets('an invalid workbook shows the error banner', (tester) async {
    picker.result = FilePickerResult([
      PlatformFile(
        name: 'broken.xlsx',
        size: 3,
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
    ]);
    final service = ImportService(
      reader: _SyncExcelReader(),
      mapper: ColumnMapper(),
      planner: ImportPlanner(),
      repository: FakeImportRepository(),
      exportService: ExportService(FakeImportRepository()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ImportScreen(service: service, onFinished: () {}),
      ),
    );

    await tester.tap(find.byKey(const Key('import_pick_file')));
    await tester.pumpAndSettle();

    expect(service.errorMessage, isNotNull);
    expect(find.byIcon(Icons.error_outline), findsWidgets);
  });
}
