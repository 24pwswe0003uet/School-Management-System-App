import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../../../employee/domain/repositories/employee_repository.dart';
import '../../../expense/domain/repositories/expense_repository.dart';
import '../../../family/domain/repositories/family_repository.dart';
import '../../../fee/domain/entities/payment_record.dart';
import '../../../fee/domain/repositories/fee_repository.dart';
import '../../../salary/domain/repositories/salary_repository.dart';
import '../../../student/domain/repositories/student_repository.dart';

/// Writes an exported workbook via the platform save dialog (default) or a test
/// seam that captures the bytes instead.
typedef DataExportSaveFile = Future<String?> Function({
  required String fileName,
  required Uint8List bytes,
  String? dialogTitle,
  String? extension,
});

/// Exports the school's core data sets (Students, Families, Employees, Fees,
/// Salaries, Expenses) to Excel. Each method reads directly from the
/// read-side repository methods and writes through a [DataExportSaveFile]
/// seam so the default behaviour opens the platform save dialog while tests
/// capture the bytes without touching the filesystem.
class DataExportService {
  DataExportService({
    required StudentRepository students,
    required FamilyRepository families,
    required EmployeeRepository employees,
    required SalaryRepository salaries,
    required ExpenseRepository expenses,
    required FeeRepository fees,
    DataExportSaveFile? saveFile,
  })  : _students = students,
        _families = families,
        _employees = employees,
        _salaries = salaries,
        _expenses = expenses,
        _fees = fees,
        _saveFile = saveFile ?? _defaultSaveFile;

  final StudentRepository _students;
  final FamilyRepository _families;
  final EmployeeRepository _employees;
  final SalaryRepository _salaries;
  final ExpenseRepository _expenses;
  final FeeRepository _fees;
  final DataExportSaveFile _saveFile;

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

  static String _stamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  static TextCellValue? _text(String? value) =>
      value == null || value.isEmpty ? null : TextCellValue(value);

  static CellValue? _date(DateTime? value) =>
      value == null ? null : DateCellValue.fromDateTime(value);

  static CellValue? _num(double? value) =>
      value == null ? null : DoubleCellValue(value);

  static String _guard(String value) {
    if (value.startsWith('=') ||
        value.startsWith('+') ||
        value.startsWith('-') ||
        value.startsWith('@')) {
      return "'$value";
    }
    return value;
  }

  Future<bool> exportStudents() async {
    final rows = await _students.searchStudents(limit: 100000);
    if (rows.isEmpty) return false;

    final workbook = Excel.createExcel();
    final sheet = workbook['Students'];
    sheet.appendRow([
      TextCellValue('Student ID'),
      TextCellValue('Name'),
      TextCellValue('Gender'),
      TextCellValue('Date of Birth'),
      TextCellValue('Class'),
      TextCellValue('Section'),
      TextCellValue('Admission Number'),
      TextCellValue('Admission Date'),
      TextCellValue('Status'),
      TextCellValue('Family ID'),
      TextCellValue('Guardian Name'),
      TextCellValue('Primary Phone'),
    ]);
    for (final row in rows) {
      final s = row.student;
      sheet.appendRow([
        TextCellValue(s.studentId),
        TextCellValue(s.name),
        TextCellValue(s.gender?.label ?? ''),
        _date(s.dateOfBirth),
        _text(s.className),
        _text(s.section),
        _text(s.admissionNumber),
        _date(s.admissionDate),
        TextCellValue(s.status.label),
        TextCellValue(row.familyId),
        _text(row.guardianName),
        _text(row.guardianPhone),
      ]);
    }
    return _save(workbook, 'students_export_${_stamp()}.xlsx');
  }

  Future<bool> exportFamilies() async {
    final rows = await _families.searchFamilies('', limit: 100000);
    if (rows.isEmpty) return false;

    final workbook = Excel.createExcel();
    final sheet = workbook['Families'];
    sheet.appendRow([
      TextCellValue('Family ID'),
      TextCellValue('Guardian Name'),
      TextCellValue('Mother Name'),
      TextCellValue('Primary Phone'),
      TextCellValue('Secondary Phone'),
      TextCellValue('Address'),
      TextCellValue('CNIC'),
      TextCellValue('Status'),
      TextCellValue('Students'),
    ]);
    for (final row in rows) {
      final f = row.family;
      sheet.appendRow([
        TextCellValue(f.familyId),
        TextCellValue(f.guardianName),
        _text(f.motherName),
        _text(f.primaryPhone),
        _text(f.secondaryPhone),
        _text(_guard(f.address ?? '')),
        _text(f.cnic),
        TextCellValue(f.status.label),
        TextCellValue('${row.studentCount}'),
      ]);
    }
    return _save(workbook, 'families_export_${_stamp()}.xlsx');
  }

  Future<bool> exportEmployees() async {
    final rows =
        await _employees.searchEmployees('', limit: 100000);
    if (rows.isEmpty) return false;

    final workbook = Excel.createExcel();
    final sheet = workbook['Employees'];
    sheet.appendRow([
      TextCellValue('Employee ID'),
      TextCellValue('Name'),
      TextCellValue('Designation'),
      TextCellValue('Category'),
      TextCellValue('Department'),
      TextCellValue('Phone'),
      TextCellValue('CNIC'),
      TextCellValue('Joining Date'),
      TextCellValue('Basic Salary'),
      TextCellValue('Notes'),
    ]);
    for (final e in rows) {
      sheet.appendRow([
        TextCellValue(e.employeeId),
        TextCellValue(e.name),
        _text(e.designation),
        TextCellValue(e.category.label),
        _text(e.department),
        _text(e.phone),
        _text(e.cnic),
        _date(e.joiningDate),
        _num(e.basicSalary),
        _text(e.notes),
      ]);
    }
    return _save(workbook, 'employees_export_${_stamp()}.xlsx');
  }

  Future<bool> exportFees() async {
    final rows = await _fees.searchFeeRecords(query: '');
    if (rows.isEmpty) return false;

    final workbook = Excel.createExcel();
    final sheet = workbook['Fees'];
    sheet.appendRow([
      TextCellValue('Student'),
      TextCellValue('Student ID'),
      TextCellValue('Class'),
      TextCellValue('Section'),
      TextCellValue('Period'),
      TextCellValue('Expected'),
      TextCellValue('Discount'),
      TextCellValue('Fine'),
      TextCellValue('Net Payable'),
      TextCellValue('Paid'),
      TextCellValue('Remaining'),
      TextCellValue('Status'),
    ]);
    for (final row in rows) {
      final r = row.record;
      final period = r.period;
      sheet.appendRow([
        TextCellValue(row.studentName),
        TextCellValue(row.studentId),
        _text(row.className),
        _text(row.section),
        TextCellValue('${period.year}-${period.month.toString().padLeft(2, '0')}'),
        _num(r.expectedAmount),
        _num(r.discount),
        _num(r.fine),
        _num(r.netPayable),
        _num(r.paidAmount),
        _num(r.remainingAmount),
        TextCellValue(r.status.label),
      ]);
    }
    return _save(workbook, 'fees_export_${_stamp()}.xlsx');
  }

  Future<bool> exportPayments() async {
    final rows = await _fees.searchFeeRecords(query: '');
    final records = <PaymentRecord>[];
    for (final row in rows) {
      final details = await _fees.getFeeRecordDetails(row.record.id);
      records.addAll(details.payments);
    }
    if (records.isEmpty) return false;

    final workbook = Excel.createExcel();
    final sheet = workbook['Payments'];
    sheet.appendRow([
      TextCellValue('Payment ID'),
      TextCellValue('Receipt Number'),
      TextCellValue('Student ID'),
      TextCellValue('Amount'),
      TextCellValue('Payment Date'),
      TextCellValue('Created By'),
      TextCellValue('Status'),
    ]);
    for (final p in records) {
      sheet.appendRow([
        TextCellValue(p.paymentId),
        _text(p.receiptNumber),
        TextCellValue(p.studentId.toString()),
        _num(p.amount),
        _date(p.paymentDate),
        _text(p.createdByName),
        TextCellValue(p.status.name),
      ]);
    }
    return _save(workbook, 'payments_export_${_stamp()}.xlsx');
  }

  Future<bool> exportSalaries() async {
    final rows = await _salaries.searchSalaries(query: '');
    if (rows.isEmpty) return false;

    final workbook = Excel.createExcel();
    final sheet = workbook['Salaries'];
    sheet.appendRow([
      TextCellValue('Salary ID'),
      TextCellValue('Employee ID'),
      TextCellValue('Employee Name'),
      TextCellValue('Designation'),
      TextCellValue('Period'),
      TextCellValue('Base Salary'),
      TextCellValue('Advance'),
      TextCellValue('Deduction'),
      TextCellValue('Other Adjustment'),
      TextCellValue('Net Amount'),
      TextCellValue('Payment Date'),
      TextCellValue('Status'),
    ]);
    for (final row in rows) {
      final r = row.record;
      final p = r.period;
      sheet.appendRow([
        TextCellValue(r.salaryRecordId),
        TextCellValue(row.employeeCode),
        TextCellValue(row.employeeName),
        _text(row.designation),
        TextCellValue('${p.year}-${p.month.toString().padLeft(2, '0')}'),
        _num(r.baseSalary),
        _num(r.advance),
        _num(r.deduction),
        _num(r.otherAdjustment),
        _num(r.netAmount),
        _date(r.paymentDate),
        TextCellValue(r.status.label),
      ]);
    }
    return _save(workbook, 'salaries_export_${_stamp()}.xlsx');
  }

  Future<bool> exportExpenses() async {
    final rows = await _expenses.searchExpenses(query: '', limit: 100000);
    if (rows.isEmpty) return false;

    final workbook = Excel.createExcel();
    final sheet = workbook['Expenses'];
    sheet.appendRow([
      TextCellValue('Expense ID'),
      TextCellValue('Date'),
      TextCellValue('Category'),
      TextCellValue('Amount'),
      TextCellValue('Description'),
      TextCellValue('Reference'),
      TextCellValue('Created By'),
    ]);
    for (final row in rows) {
      final e = row.expense;
      sheet.appendRow([
        TextCellValue(e.expenseId),
        _date(e.date),
        TextCellValue(row.category.label),
        _num(e.amount),
        _text(e.description),
        _text(e.reference),
        _text(row.createdByName),
      ]);
    }
    return _save(workbook, 'expenses_export_${_stamp()}.xlsx');
  }

  Future<bool> _save(Excel workbook, String fileName) async {
    final bytes = await workbook.encodeAsync();
    if (bytes == null) return false;
    final saved = await _saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      dialogTitle: 'Export data',
      extension: 'xlsx',
    );
    return saved != null;
  }
}
