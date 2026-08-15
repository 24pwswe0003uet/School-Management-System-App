/// A pickable employee for the salary form, carrying the fields the form
/// needs to select an employee and prefill the base salary.
class SalaryEmployeePick {
  const SalaryEmployeePick({
    required this.id,
    required this.employeeCode,
    required this.name,
    required this.designation,
    required this.basicSalary,
  });

  final int id;
  final String employeeCode;
  final String name;
  final String? designation;
  final double basicSalary;

  String get displayLabel =>
      designation == null || designation!.isEmpty
          ? name
          : '$name · $designation';
}
