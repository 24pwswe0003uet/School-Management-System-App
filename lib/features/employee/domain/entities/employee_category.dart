/// Job category of an employee.
///
/// The list is deliberately extendable: the database stores the raw [dbValue]
/// string without a CHECK constraint, so new categories can be added later
/// without a migration. Unknown stored values fall back to [otherStaff] so
/// existing screens never break.
enum EmployeeCategory {
  teacher('teacher', 'Teacher'),
  officeStaff('office_staff', 'Office Staff'),
  otherStaff('other_staff', 'Other Staff');

  const EmployeeCategory(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static EmployeeCategory fromDb(String value) {
    for (final category in EmployeeCategory.values) {
      if (category.dbValue == value) return category;
    }
    return EmployeeCategory.otherStaff;
  }
}
