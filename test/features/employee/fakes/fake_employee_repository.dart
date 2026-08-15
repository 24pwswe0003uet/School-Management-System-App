import 'package:school_office_management/features/employee/domain/entities/employee.dart';
import 'package:school_office_management/features/employee/domain/entities/employee_category.dart';
import 'package:school_office_management/features/employee/domain/entities/employee_details.dart';
import 'package:school_office_management/features/employee/domain/entities/employee_salary_record.dart';
import 'package:school_office_management/features/employee/domain/entities/employee_status.dart';
import 'package:school_office_management/features/employee/domain/repositories/employee_has_salary_history_exception.dart';
import 'package:school_office_management/features/employee/domain/repositories/employee_repository.dart';

/// In-memory [EmployeeRepository] for widget tests. Supports a simple subset of
/// the real behavior (create/update/status/delete/search/filters/details/
/// duplicates) without a database.
class FakeEmployeeRepository implements EmployeeRepository {
  FakeEmployeeRepository({List<Employee>? employees})
    : _employees = {for (final e in employees ?? <Employee>[]) e.id: e};

  final Map<int, Employee> _employees;
  final Map<int, List<EmployeeSalaryRecord>> _salaryHistory = {};

  int _nextId = 1000;

  bool failCreate = false;
  bool failSearch = false;
  bool failDetails = false;

  List<Employee> get all => _employees.values.toList();

  void seedSalaryHistory(int employeeId, List<EmployeeSalaryRecord> records) {
    _salaryHistory[employeeId] = records;
  }

  String _employeeIdFor(int id) {
    final existing = _employees[id];
    if (existing != null) return existing.employeeId;
    return 'EMP-${(all.length + 1).toString().padLeft(6, '0')}';
  }

  static String _onlyDigits(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  @override
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
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Employee name is required.');
    if (designation.trim().isEmpty) {
      throw ArgumentError('Designation is required.');
    }
    if (basicSalary < 0) {
      throw ArgumentError('Basic salary cannot be negative.');
    }
    if (failCreate) throw Exception('simulated database failure');
    final id = _nextId++;
    final now = DateTime(2026, 8, 1);
    final employee = Employee(
      id: id,
      employeeId: _employeeIdFor(id),
      name: name.trim(),
      designation: designation.trim(),
      category: category,
      department: department,
      phone: phone,
      address: address,
      cnic: cnic,
      joiningDate: joiningDate,
      basicSalary: basicSalary,
      notes: notes,
      status: EmployeeStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    _employees[id] = employee;
    return employee;
  }

  @override
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
  }) async {
    final existing = _employees[id]!;
    final updated = Employee(
      id: existing.id,
      employeeId: existing.employeeId,
      name: name.trim(),
      designation: designation.trim(),
      category: category,
      department: department,
      phone: phone,
      address: address,
      cnic: cnic,
      joiningDate: joiningDate,
      basicSalary: basicSalary,
      notes: notes,
      status: existing.status,
      createdAt: existing.createdAt,
      updatedAt: DateTime(2026, 8, 2),
    );
    _employees[id] = updated;
    return updated;
  }

  @override
  Future<Employee> deactivateEmployee(int id) async =>
      _employees[id] = _employees[id]!.copyWith(
        status: EmployeeStatus.inactive,
      );

  @override
  Future<Employee> reactivateEmployee(int id) async =>
      _employees[id] = _employees[id]!.copyWith(status: EmployeeStatus.active);

  @override
  Future<void> deleteEmployee(int id) async {
    final employee = _employees[id];
    if (employee == null) return;
    if ((_salaryHistory[id] ?? const <EmployeeSalaryRecord>[]).isNotEmpty) {
      throw EmployeeHasSalaryHistoryException(employee.employeeId);
    }
    _employees.remove(id);
  }

  @override
  Future<Employee?> getEmployee(int id) async => _employees[id];

  @override
  Future<Employee?> getEmployeeByEmployeeId(String employeeId) async {
    for (final employee in _employees.values) {
      if (employee.employeeId == employeeId) return employee;
    }
    return null;
  }

  @override
  Future<List<Employee>> searchEmployees(
    String query, {
    EmployeeCategory? category,
    EmployeeStatus? status,
    int limit = 50,
  }) async {
    if (failSearch) throw Exception('simulated database failure');
    final term = query.trim().toLowerCase();
    final termDigits = _onlyDigits(term);
    final results = _employees.values.where((employee) {
      if (category != null && employee.category != category) return false;
      if (status != null && employee.status != status) return false;
      if (term.isEmpty) return true;
      final matchesName = employee.name.toLowerCase().contains(term);
      final matchesId = employee.employeeId.toLowerCase().contains(term);
      final matchesDesignation =
          (employee.designation ?? '').toLowerCase().contains(term);
      final matchesPhone =
          termDigits.isNotEmpty &&
          (employee.phone ?? '')
              .replaceAll(RegExp(r'[^0-9]'), '')
              .contains(termDigits);
      return matchesName || matchesId || matchesDesignation || matchesPhone;
    }).toList();
    results.sort((a, b) => a.employeeId.compareTo(b.employeeId));
    return results.take(limit).toList();
  }

  @override
  Future<List<Employee>> findPossibleDuplicates({
    int? excludeId,
    String? name,
    String? phone,
    String? cnic,
  }) async {
    final trimmedName = (name ?? '').trim().toLowerCase();
    final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final cnicValue = (cnic ?? '').trim().toLowerCase();
    final results = _employees.values.where((employee) {
      if (excludeId != null && employee.id == excludeId) return false;
      final nameMatches =
          trimmedName.isNotEmpty && employee.name.toLowerCase() == trimmedName;
      final phoneMatches =
          digits.isNotEmpty &&
          (employee.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '') == digits;
      final cnicMatches =
          cnicValue.isNotEmpty &&
          (employee.cnic ?? '').trim().toLowerCase() == cnicValue;
      return (nameMatches && (phoneMatches || cnicMatches)) ||
          phoneMatches ||
          cnicMatches;
    }).toList();
    results.sort((a, b) => a.employeeId.compareTo(b.employeeId));
    return results;
  }

  @override
  Future<EmployeeDetails> getEmployeeDetails(int id) async {
    if (failDetails) throw Exception('simulated database failure');
    final employee = _employees[id];
    if (employee == null) throw ArgumentError('Employee $id does not exist.');
    final history = _salaryHistory[id] ?? const <EmployeeSalaryRecord>[];
    var totalPaid = 0.0;
    var totalPending = 0.0;
    for (final record in history) {
      if (record.status == SalaryStatus.paid) {
        totalPaid += record.netAmount;
      } else {
        totalPending += record.netAmount;
      }
    }
    return EmployeeDetails(
      employee: employee,
      salaryHistory: history,
      totalPaid: totalPaid,
      totalPending: totalPending,
    );
  }

  @override
  Future<String> nextEmployeeId() async {
    return 'EMP-${(all.length + 1).toString().padLeft(6, '0')}';
  }
}
