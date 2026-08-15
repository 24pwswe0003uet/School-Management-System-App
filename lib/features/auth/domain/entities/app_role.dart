/// Simple roles for Version 1. A full permission system is deferred.
enum AppRole {
  schoolAdmin('school_admin', 'School Admin'),
  dataEntry('data_entry', 'Data Entry Operator');

  const AppRole(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static AppRole fromDbValue(String value) => AppRole.values.firstWhere(
    (r) => r.dbValue == value,
    orElse: () => dataEntry,
  );
}
