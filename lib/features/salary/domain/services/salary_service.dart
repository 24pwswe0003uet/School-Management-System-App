import 'package:flutter/foundation.dart';

import '../entities/salary_employee_pick.dart';
import '../entities/salary_monthly_totals.dart';
import '../entities/salary_period.dart';
import '../entities/salary_record.dart';
import '../entities/salary_record_list_item.dart';
import '../entities/salary_status.dart';
import '../repositories/salary_repository.dart';

/// Holds the salary-records list/search state and exposes salary operations to
/// the screens. Follows the ChangeNotifier pattern used by the other modules.
class SalaryService extends ChangeNotifier {
  SalaryService(this._repository);

  final SalaryRepository _repository;

  /// Read operations (search, totals) go through the repository directly.
  SalaryRepository get repository => _repository;

  List<SalaryRecordListItem> _results = const [];
  bool _loading = false;
  Object? _error;
  String _query = '';
  SalaryStatus? _statusFilter;
  SalaryPeriod? _periodFilter;
  int? _yearFilter;

  List<SalaryRecordListItem> get results => _results;
  bool get isLoading => _loading;
  Object? get error => _error;
  String get query => _query;
  SalaryStatus? get statusFilter => _statusFilter;
  SalaryPeriod? get periodFilter => _periodFilter;
  int? get yearFilter => _yearFilter;

  bool get hasFilters =>
      _statusFilter != null || _periodFilter != null || _yearFilter != null;

  Future<void> refresh() => search(_query);

  Future<void> search(String query) async {
    _query = query;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _results = await _repository.searchSalaries(
        query: query,
        period: _periodFilter,
        status: _statusFilter,
        year: _yearFilter,
      );
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setStatusFilter(SalaryStatus? status) {
    _statusFilter = status;
    search(_query);
  }

  void setPeriodFilter(SalaryPeriod? period) {
    _periodFilter = period;
    search(_query);
  }

  void setYearFilter(int? year) {
    _yearFilter = year;
    search(_query);
  }

  void clearFilters() {
    _statusFilter = null;
    _periodFilter = null;
    _yearFilter = null;
    search(_query);
  }

  // Operations -----------------------------------------------------------

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
  }) {
    return _repository.createSalary(
      employeeId: employeeId,
      period: period,
      baseSalary: baseSalary,
      advance: advance,
      deduction: deduction,
      otherAdjustment: otherAdjustment,
      status: status,
      paymentDate: paymentDate,
      notes: notes,
    );
  }

  Future<SalaryRecord> updateSalary({
    required int id,
    required double baseSalary,
    required double advance,
    required double deduction,
    required double otherAdjustment,
    required SalaryStatus status,
    DateTime? paymentDate,
    String? notes,
  }) {
    return _repository.updateSalary(
      id: id,
      baseSalary: baseSalary,
      advance: advance,
      deduction: deduction,
      otherAdjustment: otherAdjustment,
      status: status,
      paymentDate: paymentDate,
      notes: notes,
    );
  }

  Future<SalaryRecord> markPaid({
    required int id,
    required DateTime paymentDate,
  }) =>
      _repository.markPaid(id: id, paymentDate: paymentDate);

  Future<void> deleteSalary(int id) => _repository.deleteSalary(id);

  Future<SalaryRecord?> getSalaryRecord(int id) =>
      _repository.getSalaryRecord(id);

  Future<SalaryRecordListItem?> getSalaryRecordDetails(int id) =>
      _repository.getSalaryRecordDetails(id);

  Future<SalaryRecord?> getSalaryForPeriod(
    int employeeId,
    SalaryPeriod period,
  ) =>
      _repository.getSalaryForPeriod(employeeId, period);

  Future<List<SalaryRecord>> salaryHistoryForEmployee(int employeeId) =>
      _repository.salaryHistoryForEmployee(employeeId);

  Future<SalaryMonthlyTotals> monthlyTotals({
    required int year,
    required int month,
  }) =>
      _repository.monthlyTotals(year: year, month: month);

  Future<List<SalaryEmployeePick>> searchEmployees(
    String query, {
    int limit = 20,
  }) =>
      _repository.searchEmployees(query, limit: limit);

  Future<List<int>> distinctYears() => _repository.distinctYears();
}
