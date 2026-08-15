import 'package:flutter/foundation.dart';

import '../entities/employee.dart';
import '../entities/employee_category.dart';
import '../entities/employee_details.dart';
import '../entities/employee_status.dart';
import '../repositories/employee_repository.dart';

/// Holds the employee list/search state and exposes employee operations to the
/// screens. Follows the ChangeNotifier pattern used by the other modules.
///
/// The list defaults to showing only active employees; All/Inactive views are
/// reached by changing the status filter.
class EmployeeService extends ChangeNotifier {
  EmployeeService(this._repository);

  final EmployeeRepository _repository;

  List<Employee> _results = const [];
  bool _loading = false;
  Object? _error;
  String _query = '';
  EmployeeCategory? _categoryFilter;
  EmployeeStatus? _statusFilter = EmployeeStatus.active;

  /// The extendable category choices offered by the create/edit form.
  static const List<EmployeeCategory> categories = EmployeeCategory.values;

  List<Employee> get results => _results;
  bool get isLoading => _loading;
  Object? get error => _error;
  String get query => _query;
  EmployeeCategory? get categoryFilter => _categoryFilter;
  EmployeeStatus? get statusFilter => _statusFilter;

  /// Reloads the current search with the current filters.
  Future<void> refresh() => search(_query);

  Future<void> search(String query) async {
    _query = query;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _results = await _repository.searchEmployees(
        query,
        category: _categoryFilter,
        status: _statusFilter,
      );
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setCategoryFilter(EmployeeCategory? category) {
    _categoryFilter = category;
    search(_query);
  }

  void setStatusFilter(EmployeeStatus? status) {
    _statusFilter = status;
    search(_query);
  }

  Future<Employee> createEmployee({
    required String name,
    required String designation,
    required EmployeeCategory category,
    String? department,
    String? phone,
    String? address,
    String? cnic,
    DateTime? joiningDate,
    double basicSalary = 0,
    String? notes,
  }) {
    return _repository.createEmployee(
      name: name,
      designation: designation,
      category: category,
      department: department,
      phone: phone,
      address: address,
      cnic: cnic,
      joiningDate: joiningDate,
      basicSalary: basicSalary,
      notes: notes,
    );
  }

  Future<Employee> updateEmployee({
    required int id,
    required String name,
    required String designation,
    required EmployeeCategory category,
    String? department,
    String? phone,
    String? address,
    String? cnic,
    DateTime? joiningDate,
    double basicSalary = 0,
    String? notes,
  }) {
    return _repository.updateEmployee(
      id: id,
      name: name,
      designation: designation,
      category: category,
      department: department,
      phone: phone,
      address: address,
      cnic: cnic,
      joiningDate: joiningDate,
      basicSalary: basicSalary,
      notes: notes,
    );
  }

  Future<Employee> deactivateEmployee(int id) =>
      _repository.deactivateEmployee(id);

  Future<Employee> reactivateEmployee(int id) =>
      _repository.reactivateEmployee(id);

  Future<void> deleteEmployee(int id) => _repository.deleteEmployee(id);

  Future<EmployeeDetails> getEmployeeDetails(int id) =>
      _repository.getEmployeeDetails(id);

  Future<List<Employee>> findPossibleDuplicates({
    int? excludeId,
    String? name,
    String? phone,
    String? cnic,
  }) {
    return _repository.findPossibleDuplicates(
      excludeId: excludeId,
      name: name,
      phone: phone,
      cnic: cnic,
    );
  }

  Future<String> nextEmployeeId() => _repository.nextEmployeeId();
}
