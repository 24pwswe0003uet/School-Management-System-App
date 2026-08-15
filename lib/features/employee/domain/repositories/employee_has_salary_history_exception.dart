/// Thrown when an attempt is made to permanently delete an employee that still
/// has salary history. Per the specification such employees are never deleted;
/// the UI offers deactivating them instead.
class EmployeeHasSalaryHistoryException implements Exception {
  const EmployeeHasSalaryHistoryException(this.employeeId);

  final String employeeId;

  @override
  String toString() =>
      'Employee $employeeId cannot be deleted because it has salary history.';
}
