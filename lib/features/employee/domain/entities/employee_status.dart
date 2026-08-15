/// Employment state of an employee.
enum EmployeeStatus {
  active,
  inactive;

  String get label => switch (this) {
    EmployeeStatus.active => 'Active',
    EmployeeStatus.inactive => 'Inactive',
  };

  String get dbValue => switch (this) {
    EmployeeStatus.active => 'active',
    EmployeeStatus.inactive => 'inactive',
  };

  static EmployeeStatus fromDb(String value) =>
      value == 'inactive' ? EmployeeStatus.inactive : EmployeeStatus.active;
}
