import 'employee_category.dart';
import 'employee_status.dart';

/// A staff member record. Names are never identifiers; the unique identifier is
/// [employeeId] (e.g. `EMP-000001`). Salary history lives in `salary_records`;
/// this row only carries the current [basicSalary] as a reference.
class Employee {
  const Employee({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.designation,
    required this.category,
    required this.department,
    required this.phone,
    required this.address,
    required this.cnic,
    required this.joiningDate,
    required this.basicSalary,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String employeeId;
  final String name;
  final String? designation;
  final EmployeeCategory category;
  final String? department;
  final String? phone;
  final String? address;
  final String? cnic;
  final DateTime? joiningDate;
  final double basicSalary;
  final String? notes;
  final EmployeeStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => status == EmployeeStatus.inactive;

  Employee copyWith({EmployeeStatus? status}) => Employee(
    id: id,
    employeeId: employeeId,
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
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
