import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/salary/domain/entities/salary_employee_pick.dart';
import 'package:school_office_management/features/salary/domain/entities/salary_period.dart';
import 'package:school_office_management/features/salary/domain/entities/salary_record.dart';
import 'package:school_office_management/features/salary/domain/entities/salary_record_list_item.dart';
import 'package:school_office_management/features/salary/domain/entities/salary_status.dart';
import 'package:school_office_management/features/salary/domain/services/salary_service.dart';
import 'package:school_office_management/features/salary/presentation/salary_form_screen.dart';
import 'package:school_office_management/features/salary/presentation/salary_record_detail_screen.dart';
import 'package:school_office_management/features/salary/presentation/salary_records_screen.dart';
import 'package:school_office_management/features/salary/presentation/salary_screen.dart';

import 'fakes/fake_salary_repository.dart';

SalaryEmployeePick pick({
  int id = 1,
  String employeeCode = 'EMP-000001',
  String name = 'Ahmed Khan',
  String? designation = 'Mathematics Teacher',
  double basicSalary = 30000,
}) {
  return SalaryEmployeePick(
    id: id,
    employeeCode: employeeCode,
    name: name,
    designation: designation,
    basicSalary: basicSalary,
  );
}

SalaryRecordListItem item({
  int id = 1,
  String salaryRecordId = 'SAL-000001',
  SalaryEmployeePick employee = const SalaryEmployeePick(
    id: 1,
    employeeCode: 'EMP-000001',
    name: 'Ahmed Khan',
    designation: 'Mathematics Teacher',
    basicSalary: 30000,
  ),
  SalaryPeriod? period,
  double base = 30000,
  double advance = 2000,
  double deduction = 500,
  double adjustment = 0,
  double net = 27500,
  SalaryStatus status = SalaryStatus.pending,
  DateTime? paymentDate,
}) {
  return SalaryRecordListItem(
    record: SalaryRecord(
      id: id,
      salaryRecordId: salaryRecordId,
      employeeId: employee.id,
      period: period ?? SalaryPeriod.current(),
      baseSalary: base,
      advance: advance,
      deduction: deduction,
      otherAdjustment: adjustment,
      netAmount: net,
      paymentDate: paymentDate,
      status: status,
      notes: null,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    ),
    employeeCode: employee.employeeCode,
    employeeName: employee.name,
    designation: employee.designation,
  );
}

SalaryService serviceWith({
  List<SalaryEmployeePick> employees = const [],
  List<SalaryRecordListItem> items = const [],
}) {
  return SalaryService(
    FakeSalaryRepository(employees: employees, items: items),
  );
}

Widget wrap(Widget child) => MaterialApp(home: child);

void useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> pushForm(
  WidgetTester tester,
  SalaryService service, {
  SalaryEmployeePick? employee,
  SalaryRecord? existing,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SalaryFormScreen(
                      salaryService: service,
                      employee: employee,
                      existing: existing,
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
}

Future<void> pushDetails(
  WidgetTester tester,
  SalaryService service,
  int recordId,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SalaryRecordDetailScreen(
                      salaryService: service,
                      recordId: recordId,
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
}

void main() {
  group('SalaryScreen hub', () {
    testWidgets('shows menu tiles and opens the records screen', (tester) async {
      final service = serviceWith();
      await tester.pumpWidget(wrap(SalaryScreen(salaryService: service)));
      await tester.pumpAndSettle();

      expect(find.text('Salary Management'), findsOneWidget);
      expect(find.byKey(const Key('salary_menu_records')), findsOneWidget);
      expect(find.byKey(const Key('salary_menu_record_salary')), findsOneWidget);

      await tester.tap(find.byKey(const Key('salary_menu_records')));
      await tester.pumpAndSettle();

      expect(find.text('Salary Records'), findsOneWidget);
      expect(find.byKey(const Key('salary_records_search')), findsOneWidget);
    });
  });

  group('SalaryRecordsScreen', () {
    testWidgets('lists records with employee identity, period, status and net',
        (tester) async {
      useLargeSurface(tester);
      final period = SalaryPeriod.current();
      final service = serviceWith(
        items: [
          item(id: 1, salaryRecordId: 'SAL-000001', period: period),
          item(
            id: 2,
            salaryRecordId: 'SAL-000002',
            employee: pick(
              id: 2,
              employeeCode: 'EMP-000002',
              name: 'Hina',
            ),
            period: period,
            advance: 6000,
            net: 24000,
            status: SalaryStatus.paid,
            paymentDate: DateTime(2026, 8, 20),
          ),
        ],
      );
      await tester.pumpWidget(wrap(SalaryRecordsScreen(salaryService: service)));
      await tester.pumpAndSettle();

      expect(find.text('Ahmed Khan'), findsOneWidget);
      expect(find.text('Hina'), findsOneWidget);
      expect(find.textContaining('EMP-000001'), findsOneWidget);
      expect(find.textContaining('EMP-000002'), findsOneWidget);
      expect(find.text('Rs 27,500'), findsWidgets);
      expect(find.text('Rs 24,000'), findsWidgets);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.textContaining('totals'), findsOneWidget);
      expect(find.byKey(const Key('salary_record_fab')), findsOneWidget);
    });

    testWidgets('search filters by employee name', (tester) async {
      useLargeSurface(tester);
      final period = SalaryPeriod.current();
      final service = serviceWith(
        items: [
          item(id: 1, salaryRecordId: 'SAL-000001', period: period),
          item(
            id: 2,
            salaryRecordId: 'SAL-000002',
            employee: pick(
              id: 2,
              employeeCode: 'EMP-000002',
              name: 'Hina',
            ),
            period: period,
          ),
        ],
      );
      await tester.pumpWidget(wrap(SalaryRecordsScreen(salaryService: service)));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('salary_records_search')),
        'Hina',
      );
      await tester.pumpAndSettle();

      expect(find.text('Hina'), findsWidgets);
      expect(find.text('Ahmed Khan'), findsNothing);
    });

    testWidgets('status filter narrows the list', (tester) async {
      useLargeSurface(tester);
      final period = SalaryPeriod.current();
      final service = serviceWith(
        items: [
          item(id: 1, salaryRecordId: 'SAL-000001', period: period),
          item(
            id: 2,
            salaryRecordId: 'SAL-000002',
            employee: pick(
              id: 2,
              employeeCode: 'EMP-000002',
              name: 'Hina',
            ),
            period: period,
            status: SalaryStatus.paid,
            paymentDate: DateTime(2026, 8, 20),
          ),
        ],
      );
      await tester.pumpWidget(wrap(SalaryRecordsScreen(salaryService: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('salary_filter_status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paid').last);
      await tester.pumpAndSettle();

      expect(find.text('Hina'), findsOneWidget);
      expect(find.text('Ahmed Khan'), findsNothing);
    });

    testWidgets('record FAB opens the create form', (tester) async {
      useLargeSurface(tester);
      final service = serviceWith(
        employees: [pick()],
      );
      await tester.pumpWidget(wrap(SalaryRecordsScreen(salaryService: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('salary_record_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Record Salary'), findsOneWidget);
      expect(find.byKey(const Key('salary_employee')), findsOneWidget);
    });
  });

  group('SalaryFormScreen', () {
    testWidgets('create flow: pick employee, autofill base, preview net, save',
        (tester) async {
      useLargeSurface(tester);
      final service = serviceWith(
        employees: [
          pick(),
          pick(
            id: 2,
            employeeCode: 'EMP-000002',
            name: 'Hina',
            basicSalary: 25000,
          ),
        ],
      );
      await pushForm(tester, service);

      await tester.tap(find.byKey(const Key('salary_employee')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('salary_employee_search')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('salary_employee_search')),
        'Ahmed',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('salary_pick_1')));
      await tester.pumpAndSettle();

      // Base is autofilled from the employee's current basic salary.
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('salary_base')))
            .controller!
            .text,
        '30000',
      );

      await tester.enterText(
        find.byKey(const Key('salary_advance')),
        '2000',
      );
      await tester.pump();

      // Live net preview: 30000 - 2000 = 28000.
      expect(find.text('Rs 28,000'), findsOneWidget);

      final save = find.byKey(const Key('salary_save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final created = service.repository
          .getSalaryForPeriod(1, SalaryPeriod.current());
      final record = await created;
      expect(record, isNotNull);
      expect(record!.salaryRecordId, 'SAL-000001');
      expect(record.netAmount, 28000);
    });

    testWidgets('duplicate create switches to editing the existing record',
        (tester) async {
      useLargeSurface(tester);
      final period = SalaryPeriod.current();
      final service = serviceWith(
        employees: [pick()],
        items: [
          item(id: 7, salaryRecordId: 'SAL-000007', period: period),
        ],
      );
      await pushForm(tester, service);

      await tester.tap(find.byKey(const Key('salary_employee')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('salary_employee_search')),
        'Ahmed',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('salary_pick_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('salary_save')));
      await tester.pumpAndSettle();

      expect(find.text('Salary already exists'), findsOneWidget);
      await tester.tap(find.byKey(const Key('salary_exists_edit')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Salary'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('salary_base')))
            .controller!
            .text,
        '30000',
      );
    });

    testWidgets('paid status requires a payment date', (tester) async {
      useLargeSurface(tester);
      final service = serviceWith(employees: [pick()]);
      await pushForm(tester, service);

      await tester.tap(find.byKey(const Key('salary_employee')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('salary_employee_search')),
        'Ahmed',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('salary_pick_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('salary_status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paid').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('salary_payment_date')), findsOneWidget);

      final save = find.byKey(const Key('salary_save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        find.text('Payment date is required when the salary is paid.'),
        findsOneWidget,
      );
    });

    testWidgets('clamped net preview warns when adjustments exceed base',
        (tester) async {
      useLargeSurface(tester);
      final service = serviceWith(employees: [pick()]);
      await pushForm(tester, service);

      await tester.enterText(find.byKey(const Key('salary_base')), '10000');
      await tester.enterText(find.byKey(const Key('salary_advance')), '12000');
      await tester.pump();

      expect(
        find.textContaining('net is clamped to Rs 0'),
        findsOneWidget,
      );
    });
  });

  group('SalaryRecordDetailScreen', () {
    testWidgets('shows components and actions for a pending record',
        (tester) async {
      useLargeSurface(tester);
      final period = SalaryPeriod.current();
      final service = serviceWith(items: [item(id: 1, period: period)]);
      await pushDetails(tester, service, 1);

      expect(find.text('Ahmed Khan'), findsOneWidget);
      expect(find.textContaining('SAL-000001'), findsOneWidget);
      expect(find.text('Rs 27,500'), findsOneWidget);
      expect(find.byKey(const Key('salary_mark_paid')), findsOneWidget);
      expect(find.byKey(const Key('salary_record_delete')), findsOneWidget);
      expect(find.byKey(const Key('salary_record_edit')), findsOneWidget);
    });

    testWidgets('mark paid opens a date picker that can be cancelled',
        (tester) async {
      useLargeSurface(tester);
      final service = serviceWith(
        items: [item(id: 1, period: SalaryPeriod.current())],
      );
      await pushDetails(tester, service, 1);

      await tester.tap(find.byKey(const Key('salary_mark_paid')));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('salary_mark_paid')), findsOneWidget);
    });

    testWidgets('delete of a pending record confirms and removes it',
        (tester) async {
      useLargeSurface(tester);
      final service = serviceWith(
        items: [item(id: 1, period: SalaryPeriod.current())],
      );
      await pushDetails(tester, service, 1);

      await tester.tap(find.byKey(const Key('salary_record_delete')));
      await tester.pumpAndSettle();

      expect(find.text('Delete salary record?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('salary_delete_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Salary Record'), findsNothing);
      expect(await service.repository.getSalaryRecord(1), isNull);
    });

    testWidgets('editing a paid record asks for confirmation first',
        (tester) async {
      useLargeSurface(tester);
      final service = serviceWith(
        items: [
          item(
            id: 1,
            period: SalaryPeriod.current(),
            status: SalaryStatus.paid,
            paymentDate: DateTime(2026, 8, 20),
          ),
        ],
      );
      await pushDetails(tester, service, 1);

      await tester.tap(find.byKey(const Key('salary_record_edit')));
      await tester.pumpAndSettle();

      expect(find.text('Edit a paid salary record?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('salary_edit_paid_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Salary'), findsOneWidget);
    });

    testWidgets('editing a pending record opens the form directly',
        (tester) async {
      useLargeSurface(tester);
      final service = serviceWith(
        items: [item(id: 1, period: SalaryPeriod.current())],
      );
      await pushDetails(tester, service, 1);

      await tester.tap(find.byKey(const Key('salary_record_edit')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Salary'), findsOneWidget);
    });
  });
}
