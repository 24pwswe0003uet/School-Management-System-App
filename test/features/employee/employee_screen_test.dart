import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/employee/domain/entities/employee.dart';
import 'package:school_office_management/features/employee/domain/entities/employee_category.dart';
import 'package:school_office_management/features/employee/domain/entities/employee_salary_record.dart';
import 'package:school_office_management/features/employee/domain/entities/employee_status.dart';
import 'package:school_office_management/features/employee/domain/services/employee_service.dart';
import 'package:school_office_management/features/employee/presentation/employee_details_screen.dart';
import 'package:school_office_management/features/employee/presentation/employee_form_screen.dart';
import 'package:school_office_management/features/employee/presentation/employee_list_screen.dart';
import 'package:school_office_management/features/salary/domain/services/salary_service.dart';

import 'fakes/fake_employee_repository.dart';
import '../salary/fakes/fake_salary_repository.dart';

SalaryService salaryService() => SalaryService(FakeSalaryRepository());

Employee buildEmployee({
  int id = 1,
  String employeeId = 'EMP-000001',
  String name = 'Ahmed Khan',
  String designation = 'Mathematics Teacher',
  EmployeeCategory category = EmployeeCategory.teacher,
  String? department,
  String? phone = '0300-1234567',
  String? address,
  String? cnic,
  DateTime? joiningDate,
  double basicSalary = 25000,
  String? notes,
  EmployeeStatus status = EmployeeStatus.active,
}) {
  return Employee(
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
    status: status,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );
}

EmployeeSalaryRecord buildSalaryRecord({
  int id = 1,
  DateTime? periodStart,
  double netAmount = 0,
  SalaryStatus status = SalaryStatus.paid,
}) {
  final start = periodStart ?? DateTime(2026, 8, 1);
  return EmployeeSalaryRecord(
    id: id,
    periodStart: start,
    periodEnd: DateTime(start.year, start.month + 1, 0),
    baseSalary: 25000,
    advance: 0,
    deduction: 0,
    netAmount: netAmount,
    paymentDate: status == SalaryStatus.paid ? DateTime(2026, 8, 31) : null,
    status: status,
  );
}

EmployeeService serviceWith(List<Employee> employees) =>
    EmployeeService(FakeEmployeeRepository(employees: employees));

Widget wrap(Widget child) => MaterialApp(home: child);

/// Gives the details screen enough room that the lazy ListView builds every
/// row (the test font is much wider than a real font).
void useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> pumpList(WidgetTester tester, EmployeeService service) async {
  await tester.pumpWidget(
    wrap(EmployeeListScreen(
      employeeService: service,
      salaryService: salaryService(),
    )),
  );
  await tester.pumpAndSettle();
}

/// Pushes the employee form and returns a growable holder that receives the
/// popped result once the form is saved and popped.
Future<List<Employee?>> pushAndOpen(
  WidgetTester tester,
  EmployeeService service, {
  Employee? existing,
}) async {
  final result = <Employee?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result.add(
                  await Navigator.of(context).push<Employee>(
                    MaterialPageRoute(
                      builder: (_) => EmployeeFormScreen(
                        employeeService: service,
                        salaryService: salaryService(),
                        existing: existing,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('open form'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open form'));
  await tester.pumpAndSettle();
  return result;
}

/// Fills the given fields and taps Save using fixed pumps — `pumpAndSettle`
/// cannot be used because the loading spinner animates while the
/// duplicate-warning dialog is open.
Future<void> submitForm(
  WidgetTester tester, {
  String? name,
  String? designation,
  String? phone,
}) async {
  if (name != null) {
    await tester.enterText(find.byKey(const Key('employee_name')), name);
  }
  if (designation != null) {
    await tester.enterText(
      find.byKey(const Key('employee_designation')),
      designation,
    );
  }
  if (phone != null) {
    await tester.enterText(find.byKey(const Key('employee_phone')), phone);
  }
  final save = find.byKey(const Key('employee_save'));
  await tester.ensureVisible(save);
  await tester.pump();
  await tester.tap(save);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  group('EmployeeListScreen', () {
    testWidgets('lists employees with IDs, categories and statuses', (
      tester,
    ) async {
      final service = serviceWith([
        buildEmployee(),
        buildEmployee(
          id: 2,
          employeeId: 'EMP-000002',
          name: 'Usman Ali',
          designation: 'Office Clerk',
          category: EmployeeCategory.officeStaff,
          phone: '0300-9999999',
        ),
      ]);
      await pumpList(tester, service);

      expect(find.textContaining('EMP-000001'), findsOneWidget);
      expect(find.textContaining('EMP-000002'), findsOneWidget);
      expect(find.text('Ahmed Khan'), findsOneWidget);
      expect(find.text('Usman Ali'), findsOneWidget);
      expect(find.text('Active'), findsNWidgets(3));
    });

    testWidgets('shows an empty state when there are no employees', (
      tester,
    ) async {
      await pumpList(tester, serviceWith([]));

      expect(find.text('No staff found.'), findsOneWidget);
    });

    testWidgets('search filters the employee list', (tester) async {
      final service = serviceWith([
        buildEmployee(),
        buildEmployee(
          id: 2,
          employeeId: 'EMP-000002',
          name: 'Usman Ali',
          designation: 'Office Clerk',
        ),
      ]);
      await pumpList(tester, service);

      await tester.enterText(
        find.byKey(const Key('employee_search_field')),
        'usman',
      );
      await tester.pumpAndSettle();

      expect(find.text('Usman Ali'), findsOneWidget);
      expect(find.text('Ahmed Khan'), findsNothing);
    });

    testWidgets('search matches an employee ID', (tester) async {
      final service = serviceWith([buildEmployee()]);
      await pumpList(tester, service);

      await tester.enterText(
        find.byKey(const Key('employee_search_field')),
        'EMP-000001',
      );
      await tester.pumpAndSettle();

      expect(find.text('Ahmed Khan'), findsOneWidget);
    });

    testWidgets('category filter narrows the list', (tester) async {
      final service = serviceWith([
        buildEmployee(),
        buildEmployee(
          id: 2,
          employeeId: 'EMP-000002',
          name: 'Usman Ali',
          designation: 'Office Clerk',
          category: EmployeeCategory.officeStaff,
        ),
      ]);
      await pumpList(tester, service);

      await tester.tap(find.byKey(const Key('employee_category_filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Office Staff').last);
      await tester.pumpAndSettle();

      expect(find.text('Usman Ali'), findsOneWidget);
      expect(find.text('Ahmed Khan'), findsNothing);
    });

    testWidgets('shows an error state and recovers via retry', (tester) async {
      final repository = FakeEmployeeRepository(employees: [buildEmployee()]);
      repository.failSearch = true;
      final service = EmployeeService(repository);
      await pumpList(tester, service);

      expect(find.text('Staff could not be loaded.'), findsOneWidget);

      repository.failSearch = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Ahmed Khan'), findsOneWidget);
    });

    testWidgets('opens the create form via the FAB', (tester) async {
      final service = serviceWith([]);
      await pumpList(tester, service);

      await tester.tap(find.byKey(const Key('employee_add_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Add Staff'), findsWidgets);
      expect(find.byKey(const Key('employee_name')), findsOneWidget);
      expect(find.text('EMP-000001'), findsOneWidget);
    });

    testWidgets('tapping an employee card opens its details', (tester) async {
      final service = serviceWith([buildEmployee()]);
      await pumpList(tester, service);

      await tester.tap(find.text('Ahmed Khan'));
      await tester.pumpAndSettle();

      expect(find.text('Staff Details'), findsOneWidget);
      expect(find.textContaining('EMP-000001'), findsWidgets);
    });
  });

  group('EmployeeFormScreen', () {
    testWidgets('validates required and malformed fields', (tester) async {
      useLargeSurface(tester);
      final service = serviceWith([]);
      await pushAndOpen(tester, service);

      await tester.enterText(
        find.byKey(const Key('employee_phone')),
        'not a phone',
      );
      await tester.enterText(find.byKey(const Key('employee_cnic')), '123');
      await tester.enterText(
        find.byKey(const Key('employee_basic_salary')),
        '-5',
      );
      await submitForm(tester);

      expect(find.text('Please enter the name.'), findsOneWidget);
      expect(find.text('Please enter the designation.'), findsOneWidget);
      expect(
        find.text('Phone can only contain digits, spaces, + or -.'),
        findsOneWidget,
      );
      expect(find.text('CNIC must be exactly 13 digits.'), findsOneWidget);
      expect(find.text('Salary cannot be negative.'), findsOneWidget);
      expect(find.text('EMP-000001'), findsOneWidget);
    });

    testWidgets('creates an employee and pops with the result', (tester) async {
      useLargeSurface(tester);
      final service = serviceWith([]);
      final result = await pushAndOpen(tester, service);

      await submitForm(tester, name: 'Usman Ali', designation: 'Clerk');

      expect(result.single?.name, 'Usman Ali');
      expect(result.single?.designation, 'Clerk');
      expect(result.single?.employeeId, 'EMP-000001');
      expect(result.single?.category, EmployeeCategory.teacher);
    });

    testWidgets('duplicate warning Cancel aborts the save', (tester) async {
      useLargeSurface(tester);
      final repository = FakeEmployeeRepository(
        employees: [buildEmployee(name: 'Ahmed Khan', phone: '0300-1234567')],
      );
      final service = EmployeeService(repository);
      await pushAndOpen(tester, service);

      await submitForm(
        tester,
        name: 'Ahmed Khan',
        designation: 'Mathematics Teacher',
        phone: '0300-1234567',
      );

      expect(find.text('Possible existing staff'), findsOneWidget);
      expect(find.byKey(const Key('dup_EMP-000001')), findsOneWidget);

      await tester.tap(find.byKey(const Key('dup_cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Possible existing staff'), findsNothing);
      expect(repository.all, hasLength(1));
      expect(find.text('Add Staff'), findsWidgets);
    });

    testWidgets('Create anyway saves a second employee', (tester) async {
      useLargeSurface(tester);
      final service = serviceWith([
        buildEmployee(name: 'Ahmed Khan', phone: '0300-1234567'),
      ]);
      final result = await pushAndOpen(tester, service);

      await submitForm(
        tester,
        name: 'Ahmed Khan',
        designation: 'Mathematics Teacher',
        phone: '0300-1234567',
      );

      await tester.tap(find.byKey(const Key('dup_create_anyway')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(result.single?.employeeId, 'EMP-000002');
    });

    testWidgets('View opens the matched employee profile', (tester) async {
      useLargeSurface(tester);
      final service = serviceWith([
        buildEmployee(name: 'Ahmed Khan', phone: '0300-1234567'),
      ]);
      await pushAndOpen(tester, service);

      await submitForm(
        tester,
        name: 'Ahmed Khan',
        designation: 'Mathematics Teacher',
        phone: '0300-1234567',
      );

      await tester.tap(find.byKey(const Key('dup_EMP-000001')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Staff Details'), findsOneWidget);
      expect(find.text('Ahmed Khan'), findsWidgets);
    });

    testWidgets('edit mode prefills values and saves changes', (tester) async {
      useLargeSurface(tester);
      final service = serviceWith([buildEmployee()]);
      final result = await pushAndOpen(
        tester,
        service,
        existing: buildEmployee(),
      );

      expect(find.text('Edit Staff'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Ahmed Khan'), findsOneWidget);
      expect(find.text('Mathematics Teacher'), findsOneWidget);

      await submitForm(tester, name: 'New Name');

      expect(result.single?.name, 'New Name');
      expect(result.single?.employeeId, 'EMP-000001');
    });
  });

  group('EmployeeDetailsScreen', () {
    Future<void> pumpDetails(
      WidgetTester tester,
      EmployeeService service,
      int employeeId,
    ) async {
      await tester.pumpWidget(
        wrap(EmployeeDetailsScreen(
          employeeService: service,
          salaryService: salaryService(),
          employeeId: employeeId,
        )),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows info, salary summary and history', (tester) async {
      useLargeSurface(tester);
      final employee = buildEmployee(basicSalary: 25000);
      final repository = FakeEmployeeRepository(employees: [employee]);
      repository.seedSalaryHistory(employee.id, [
        buildSalaryRecord(
          id: 1,
          periodStart: DateTime(2026, 8, 1),
          netAmount: 23500,
          status: SalaryStatus.paid,
        ),
        buildSalaryRecord(
          id: 2,
          periodStart: DateTime(2026, 9, 1),
          netAmount: 25000,
          status: SalaryStatus.pending,
        ),
      ]);
      await pumpDetails(tester, EmployeeService(repository), employee.id);

      expect(find.text('Staff Details'), findsOneWidget);
      expect(find.textContaining('EMP-000001'), findsWidgets);
      expect(find.text('Ahmed Khan'), findsWidgets);
      expect(find.text('Mathematics Teacher'), findsOneWidget);
      expect(find.text('Teacher'), findsOneWidget);
      expect(find.text('0300-1234567'), findsOneWidget);
      expect(find.text('Rs 25,000'), findsWidgets);
      expect(find.text('Paid so far'), findsOneWidget);
      expect(find.text('Pending'), findsNWidgets(2));
      expect(find.text('Rs 23,500'), findsNWidgets(2));
      expect(find.text('Salary History (2)'), findsOneWidget);
      expect(find.text('Aug 2026'), findsOneWidget);
      expect(find.text('Sep 2026'), findsOneWidget);
    });

    testWidgets('deactivate and reactivate toggle the status', (tester) async {
      useLargeSurface(tester);
      final employee = buildEmployee();
      final repository = FakeEmployeeRepository(employees: [employee]);
      await pumpDetails(tester, EmployeeService(repository), employee.id);

      expect(find.text('Active'), findsWidgets);
      await tester.tap(find.byKey(const Key('employee_status_toggle')));
      await tester.pumpAndSettle();

      expect(find.text('Inactive'), findsWidgets);
      expect(find.text('Reactivate'), findsOneWidget);

      await tester.tap(find.byKey(const Key('employee_status_toggle')));
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsWidgets);
    });

    testWidgets('delete is blocked when salary history exists', (
      tester,
    ) async {
      useLargeSurface(tester);
      final employee = buildEmployee();
      final repository = FakeEmployeeRepository(employees: [employee]);
      repository.seedSalaryHistory(employee.id, [
        buildSalaryRecord(netAmount: 20000, status: SalaryStatus.paid),
      ]);
      await pumpDetails(tester, EmployeeService(repository), employee.id);

      await tester.tap(find.byKey(const Key('employee_delete')));
      await tester.pumpAndSettle();

      expect(find.text('Employee cannot be deleted'), findsOneWidget);
      expect(
        find.textContaining('Staff with salary history are never deleted'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('employee_deactivate_from_delete')));
      await tester.pumpAndSettle();

      expect(find.text('Inactive'), findsWidgets);
      expect(repository.all.single.status, EmployeeStatus.inactive);
    });

    testWidgets('deleting an employee with no salary confirms and pops', (
      tester,
    ) async {
      useLargeSurface(tester);
      final employee = buildEmployee();
      final repository = FakeEmployeeRepository(employees: [employee]);
      final service = EmployeeService(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EmployeeDetailsScreen(
                          employeeService: service,
                          salaryService: salaryService(),
                          employeeId: employee.id,
                        ),
                      ),
                    );
                  },
                  child: const Text('open details'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open details'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('employee_delete')));
      await tester.pumpAndSettle();

      expect(find.text('Delete employee?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('employee_delete_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Staff Details'), findsNothing);
      expect(repository.all, isEmpty);
    });

    testWidgets('edit opens the prefilled form and details refresh', (
      tester,
    ) async {
      useLargeSurface(tester);
      final employee = buildEmployee();
      final service = serviceWith([employee]);
      await pumpDetails(tester, service, employee.id);

      await tester.tap(find.byKey(const Key('employee_edit')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Staff'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('employee_name')),
        'Updated Name',
      );
      final save = find.byKey(const Key('employee_save'));
      await tester.ensureVisible(save);
      await tester.pump();
      await tester.tap(save);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Staff Details'), findsOneWidget);
      expect(find.text('Updated Name'), findsWidgets);
    });
  });
}
