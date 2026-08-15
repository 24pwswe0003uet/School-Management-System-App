import 'package:school_office_management/features/salary/application/salary_calculator.dart';
import 'package:school_office_management/features/salary/domain/entities/salary_employee_pick.dart';
import 'package:school_office_management/features/salary/domain/entities/salary_monthly_totals.dart';
import 'package:school_office_management/features/salary/domain/entities/salary_period.dart';
import 'package:school_office_management/features/salary/domain/entities/salary_record.dart';
import 'package:school_office_management/features/salary/domain/entities/salary_record_list_item.dart';
import 'package:school_office_management/features/salary/domain/entities/salary_status.dart';
import 'package:school_office_management/features/salary/domain/repositories/salary_period_exists_exception.dart';
import 'package:school_office_management/features/salary/domain/repositories/salary_repository.dart';

/// In-memory [SalaryRepository] for widget tests. Mirrors the repository's
/// business rules (auto codes, central net calculation, one record per
/// employee and month) without a database.
class FakeSalaryRepository implements SalaryRepository {
  FakeSalaryRepository({
    List<SalaryEmployeePick>? employees,
    List<SalaryRecordListItem>? items,
    this.error,
  })  : employees = [...?employees],
        items = [...?items];

  final List<SalaryEmployeePick> employees;
  final List<SalaryRecordListItem> items;

  /// When set, every repository call throws it.
  Object? error;

  bool failCreate = false;
  bool failSearchEmployees = false;

  SalaryEmployeePick? _employeeFor(int employeeId) {
    for (final employee in employees) {
      if (employee.id == employeeId) return employee;
    }
    return null;
  }

  SalaryRecordListItem? _itemFor(int id) {
    for (final item in items) {
      if (item.record.id == id) return item;
    }
    return null;
  }

  void _throwIfError() {
    final error = this.error;
    if (error != null) throw error;
  }

  @override
  Future<SalaryRecord> createSalary({
    required int employeeId,
    required SalaryPeriod period,
    required double baseSalary,
    required double advance,
    required double deduction,
    required double otherAdjustment,
    required SalaryStatus status,
    DateTime? paymentDate,
    String? notes,
  }) async {
    _throwIfError();
    if (failCreate) throw StateError('simulated create failure');
    if (_employeeFor(employeeId) == null) {
      throw ArgumentError('Employee does not exist.');
    }
    for (final item in items) {
      if (item.record.employeeId == employeeId &&
          item.record.period == period) {
        final employee = _employeeFor(employeeId)!;
        throw SalaryPeriodExistsException(
          employeeCode: employee.employeeCode,
          period: period,
        );
      }
    }
    final employee = _employeeFor(employeeId)!;
    final id = items.isEmpty ? 1 : items.last.record.id + 1;
    final code = 'SAL-${id.toString().padLeft(6, '0')}';
    final net = SalaryCalculator.netPayable(
      base: baseSalary,
      advance: advance,
      deduction: deduction,
      otherAdjustment: otherAdjustment,
    );
    final now = DateTime.utc(2026, 8, 15);
    final record = SalaryRecord(
      id: id,
      salaryRecordId: code,
      employeeId: employeeId,
      period: period,
      baseSalary: baseSalary,
      advance: advance,
      deduction: deduction,
      otherAdjustment: otherAdjustment,
      netAmount: net,
      paymentDate: paymentDate,
      status: status,
      notes: _emptyToNull(notes),
      createdAt: now,
      updatedAt: now,
    );
    items.add(
      SalaryRecordListItem(
        record: record,
        employeeCode: employee.employeeCode,
        employeeName: employee.name,
        designation: employee.designation,
      ),
    );
    return record;
  }

  @override
  Future<SalaryRecord> updateSalary({
    required int id,
    required double baseSalary,
    required double advance,
    required double deduction,
    required double otherAdjustment,
    required SalaryStatus status,
    DateTime? paymentDate,
    String? notes,
  }) async {
    _throwIfError();
    final item = _itemFor(id);
    if (item == null) throw ArgumentError('Salary record not found.');
    final record = item.record;
    final net = SalaryCalculator.netPayable(
      base: baseSalary,
      advance: advance,
      deduction: deduction,
      otherAdjustment: otherAdjustment,
    );
    final updated = SalaryRecord(
      id: record.id,
      salaryRecordId: record.salaryRecordId,
      employeeId: record.employeeId,
      period: record.period,
      baseSalary: baseSalary,
      advance: advance,
      deduction: deduction,
      otherAdjustment: otherAdjustment,
      netAmount: net,
      paymentDate: status == SalaryStatus.paid ? paymentDate : null,
      status: status,
      notes: _emptyToNull(notes),
      createdAt: record.createdAt,
      updatedAt: DateTime.utc(2026, 8, 20),
    );
    final index = items.indexWhere((e) => e.record.id == id);
    items[index] = SalaryRecordListItem(
      record: updated,
      employeeCode: item.employeeCode,
      employeeName: item.employeeName,
      designation: item.designation,
    );
    return updated;
  }

  @override
  Future<SalaryRecord> markPaid({
    required int id,
    required DateTime paymentDate,
  }) async {
    _throwIfError();
    final item = _itemFor(id);
    if (item == null) throw ArgumentError('Salary record not found.');
    final record = item.record;
    final updated = SalaryRecord(
      id: record.id,
      salaryRecordId: record.salaryRecordId,
      employeeId: record.employeeId,
      period: record.period,
      baseSalary: record.baseSalary,
      advance: record.advance,
      deduction: record.deduction,
      otherAdjustment: record.otherAdjustment,
      netAmount: record.netAmount,
      paymentDate: paymentDate,
      status: SalaryStatus.paid,
      notes: record.notes,
      createdAt: record.createdAt,
      updatedAt: DateTime.utc(2026, 8, 20),
    );
    final index = items.indexWhere((e) => e.record.id == id);
    items[index] = SalaryRecordListItem(
      record: updated,
      employeeCode: item.employeeCode,
      employeeName: item.employeeName,
      designation: item.designation,
    );
    return updated;
  }

  @override
  Future<void> deleteSalary(int id) async {
    _throwIfError();
    items.removeWhere((e) => e.record.id == id);
  }

  @override
  Future<SalaryRecord?> getSalaryRecord(int id) async {
    _throwIfError();
    return _itemFor(id)?.record;
  }

  @override
  Future<SalaryRecordListItem?> getSalaryRecordDetails(int id) async {
    _throwIfError();
    return _itemFor(id);
  }

  @override
  Future<SalaryRecord?> getSalaryForPeriod(
    int employeeId,
    SalaryPeriod period,
  ) async {
    _throwIfError();
    for (final item in items) {
      if (item.record.employeeId == employeeId &&
          item.record.period == period) {
        return item.record;
      }
    }
    return null;
  }

  @override
  Future<List<SalaryRecord>> salaryHistoryForEmployee(int employeeId) async {
    _throwIfError();
    final history = items
        .where((e) => e.record.employeeId == employeeId)
        .map((e) => e.record)
        .toList()
      ..sort((a, b) => b.period.year == a.period.year
          ? b.period.month.compareTo(a.period.month)
          : b.period.year.compareTo(a.period.year));
    return history;
  }

  @override
  Future<List<SalaryRecordListItem>> searchSalaries({
    String query = '',
    SalaryPeriod? period,
    SalaryStatus? status,
    int? year,
    int? employeeId,
  }) async {
    _throwIfError();
    final term = query.trim().toLowerCase();
    final result = <SalaryRecordListItem>[];
    for (final item in items) {
      if (employeeId != null && item.record.employeeId != employeeId) {
        continue;
      }
      if (period != null && item.record.period != period) continue;
      if (status != null && item.record.status != status) continue;
      if (year != null && item.record.period.year != year) continue;
      if (term.isNotEmpty &&
          !item.employeeCode.toLowerCase().contains(term) &&
          !item.employeeName.toLowerCase().contains(term)) {
        continue;
      }
      result.add(item);
    }
    return result;
  }

  @override
  Future<SalaryMonthlyTotals> monthlyTotals({
    required int year,
    required int month,
  }) async {
    _throwIfError();
    final period = SalaryPeriod(year: year, month: month);
    final monthItems = items
        .where(
          (e) =>
              e.record.period.year == year && e.record.period.month == month,
        )
        .toList();
    var totalBase = 0.0;
    var totalAdvance = 0.0;
    var totalDeduction = 0.0;
    var totalAdjustment = 0.0;
    var netPayable = 0.0;
    var paid = 0.0;
    var pending = 0.0;
    for (final item in monthItems) {
      final record = item.record;
      totalBase += record.baseSalary;
      totalAdvance += record.advance;
      totalDeduction += record.deduction;
      totalAdjustment += record.otherAdjustment;
      netPayable += record.netAmount;
      if (record.isPaid) {
        paid += record.netAmount;
      } else {
        pending += record.netAmount;
      }
    }
    return SalaryMonthlyTotals(
      period: period,
      recordCount: monthItems.length,
      totalBase: totalBase,
      totalAdvance: totalAdvance,
      totalDeduction: totalDeduction,
      totalAdjustment: totalAdjustment,
      netPayable: netPayable,
      totalPaid: paid,
      totalPending: pending,
    );
  }

  @override
  Future<List<SalaryEmployeePick>> searchEmployees(
    String query, {
    int limit = 20,
  }) async {
    _throwIfError();
    if (failSearchEmployees) throw StateError('simulated search failure');
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return const [];
    final result = <SalaryEmployeePick>[];
    for (final employee in employees) {
      if (employee.employeeCode.toLowerCase().contains(term) ||
          employee.name.toLowerCase().contains(term)) {
        result.add(employee);
      }
      if (result.length >= limit) break;
    }
    return result;
  }

  @override
  Future<List<int>> distinctYears() async {
    _throwIfError();
    final years = <int>{};
    for (final item in items) {
      years.add(item.record.period.year);
    }
    final list = years.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  static String? _emptyToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
