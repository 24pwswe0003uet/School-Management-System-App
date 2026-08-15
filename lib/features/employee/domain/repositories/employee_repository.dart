import '../entities/employee.dart';
import '../entities/employee_category.dart';
import '../entities/employee_details.dart';
import '../entities/employee_status.dart';

/// Data operations for the Employee Management module.
///
/// Implementations enforce: name is required, employee IDs are unique, an
/// employee with salary history cannot be deleted (only deactivated), and
/// salary records can never reference an employee that does not exist.
abstract interface class EmployeeRepository {
  Future<Employee> createEmployee({
    required String name,
    required String designation,
    required EmployeeCategory category,
    String? department,
    String? phone,
    String? address,
    String? cnic,
    DateTime? joiningDate,
    double basicSalary,
    String? notes,
  });

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
    double basicSalary,
    String? notes,
  });

  Future<Employee> deactivateEmployee(int id);

  Future<Employee> reactivateEmployee(int id);

  /// Permanently deletes an employee with no salary history. Throws
  /// [EmployeeHasSalaryHistoryException] when salary records reference the
  /// employee.
  Future<void> deleteEmployee(int id);

  Future<Employee?> getEmployee(int id);

  Future<Employee?> getEmployeeByEmployeeId(String employeeId);

  /// Searches by employee ID, name, designation, or phone. When [category] or
  /// [status] are given the results are filtered to them; otherwise every
  /// employee matches.
  Future<List<Employee>> searchEmployees(
    String query, {
    EmployeeCategory? category,
    EmployeeStatus? status,
    int limit = 50,
  });

  /// Finds employees that may be duplicates of the given data, using name,
  /// phone, and CNIC. Never auto-merges — callers show the list and let the
  /// operator decide.
  Future<List<Employee>> findPossibleDuplicates({
    int? excludeId,
    String? name,
    String? phone,
    String? cnic,
  });

  Future<EmployeeDetails> getEmployeeDetails(int id);

  /// The next available generated ID, e.g. `EMP-000002`.
  Future<String> nextEmployeeId();
}
