import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/import/domain/services/excel_reader.dart';

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
  return Uint8List.fromList(await excel.encodeAsync() ?? const []);
}

void main() {
  final reader = ExcelReader();

  test('load exposes sheet names and readSheet returns plain values', () async {
    final bytes = await buildWorkbook([
      (
        'Students',
        [
          [TextCellValue('Student Name'), TextCellValue('Age')],
          [TextCellValue('Ali Khan'), const IntCellValue(12)],
        ],
      ),
      (
        'Fees',
        [
          [TextCellValue('Student Name')],
          [TextCellValue('Ali Khan')],
        ],
      ),
    ]);

    final loaded = await reader.load(bytes, fileName: 'students.xlsx');
    expect(loaded.fileName, 'students.xlsx');
    expect(loaded.sheetNames, ['Students', 'Fees']);

    final sheet = reader.readSheet('Students');
    expect(sheet.name, 'Students');
    expect(sheet.headers, ['Student Name', 'Age']);
    expect(sheet.rows, hasLength(1));
    expect(sheet.rows.first, ['Ali Khan', 12]);
  });

  test('cell types are preserved as numbers, booleans and dates', () async {
    final dob = DateCellValue.fromDateTime(DateTime(2014, 5, 1));
    final bytes = await buildWorkbook([
      (
        'Students',
        [
          [
            TextCellValue('Name'),
            TextCellValue('Score'),
            TextCellValue('Active'),
            TextCellValue('DOB'),
          ],
          [
            TextCellValue('Ali Khan'),
            const DoubleCellValue(88.5),
            const BoolCellValue(true),
            dob,
          ],
        ],
      ),
    ]);

    await reader.load(bytes, fileName: 'types.xlsx');
    final sheet = reader.readSheet('Students');
    expect(sheet.rows.single[1], 88.5);
    expect(sheet.rows.single[2], true);
    expect(sheet.rows.single[3], DateTime(2014, 5, 1));
  });

  test('first non-empty row is the header; blank rows are trimmed', () async {
    final bytes = await buildWorkbook([
      (
        'Students',
        [
          [null, null],
          [null],
          [TextCellValue('Name')],
          [TextCellValue('Ali Khan')],
          [TextCellValue('Sana')],
          [null, null],
        ],
      ),
    ]);

    await reader.load(bytes, fileName: 'blank.xlsx');
    final sheet = reader.readSheet('Students');
    expect(sheet.headers, ['Name']);
    expect(sheet.rows, [
      ['Ali Khan'],
      ['Sana'],
    ]);
  });

  test(
    'rows wider than the header are truncated, shorter rows padded',
    () async {
      final bytes = await buildWorkbook([
        (
          'Students',
          [
            [
              TextCellValue('Name'),
              TextCellValue('Class'),
              TextCellValue('Section'),
            ],
            [
              TextCellValue('Ali Khan'),
              TextCellValue('5'),
              TextCellValue('A'),
              TextCellValue('extra'),
            ],
            [TextCellValue('Sana')],
          ],
        ),
      ]);

      await reader.load(bytes, fileName: 'ragged.xlsx');
      final sheet = reader.readSheet('Students');
      expect(sheet.headers, ['Name', 'Class', 'Section']);
      expect(sheet.rows, [
        ['Ali Khan', '5', 'A'],
        ['Sana', null, null],
      ]);
    },
  );

  test('duplicate headers are rejected', () async {
    final bytes = await buildWorkbook([
      (
        'Students',
        [
          [TextCellValue('Name'), TextCellValue('Name')],
          [TextCellValue('Ali Khan'), TextCellValue('x')],
        ],
      ),
    ]);

    await reader.load(bytes, fileName: 'dup.xlsx');
    expect(
      () => reader.readSheet('Students'),
      throwsA(
        isA<ImportFileException>().having(
          (e) => e.message,
          'message',
          contains('Duplicate column headers'),
        ),
      ),
    );
  });

  test('an empty worksheet is rejected', () async {
    final bytes = await buildWorkbook([('Students', <List<CellValue?>>[])]);

    await reader.load(bytes, fileName: 'empty.xlsx');
    expect(
      () => reader.readSheet('Students'),
      throwsA(
        isA<ImportFileException>().having(
          (e) => e.message,
          'message',
          contains('empty'),
        ),
      ),
    );
  });

  test('corrupt bytes are rejected with a friendly message', () async {
    final bytes = Uint8List.fromList(List.filled(200, 7));
    await expectLater(
      reader.load(bytes, fileName: 'corrupt.xlsx'),
      throwsA(isA<ImportFileException>()),
    );
  });

  test('reading a missing sheet is rejected', () async {
    final bytes = await buildWorkbook([
      (
        'Students',
        [
          [TextCellValue('Name')],
          [TextCellValue('Ali Khan')],
        ],
      ),
    ]);
    await reader.load(bytes, fileName: 'one.xlsx');
    expect(
      () => reader.readSheet('Fees'),
      throwsA(
        isA<ImportFileException>().having(
          (e) => e.message,
          'message',
          contains('not found'),
        ),
      ),
    );
  });
}
