import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/auth/domain/entities/app_role.dart';
import 'package:school_office_management/features/auth/domain/entities/app_user.dart';
import 'package:school_office_management/features/auth/domain/repositories/auth_repository.dart';
import 'package:school_office_management/features/auth/domain/services/auth_service.dart';
import 'package:school_office_management/features/dashboard/dashboard_screen.dart';
import 'package:school_office_management/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:school_office_management/features/dashboard/domain/entities/recent_activity_item.dart';
import 'package:school_office_management/features/dashboard/domain/services/dashboard_service.dart';
import 'package:school_office_management/features/employee/domain/services/employee_service.dart';
import 'package:school_office_management/features/family/domain/services/family_service.dart';
import 'package:school_office_management/features/fee/application/fee_service.dart';
import 'package:school_office_management/features/salary/domain/services/salary_service.dart';
import 'package:school_office_management/features/student/domain/services/student_service.dart';

import '../family/fakes/fake_family_repository.dart';
import '../fee/fakes/fake_fee_repository.dart';
import '../import/fakes/fake_import_repository.dart';
import '../salary/fakes/fake_salary_repository.dart';
import '../student/fakes/fake_student_repository.dart';
import '../employee/fakes/fake_employee_repository.dart';
import 'fakes/fake_dashboard_repository.dart';

class _AlwaysAdminAuthRepository implements AuthRepository {
  @override
  Future<AppUser?> authenticate(String identifier, String password) async {
    return AppUser(
      id: 1,
      username: 'admin',
      displayName: 'Admin User',
      role: AppRole.schoolAdmin,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<AppUser> createUser({
    required String username,
    required String password,
    required String displayName,
    AppRole role = AppRole.dataEntry,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> hasAnyUser() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AuthService> loggedInAuthService() async {
    final service = AuthService(_AlwaysAdminAuthRepository());
    await service.refreshSetupStatus();
    final result = await service.login('admin', 'password');
    expect(result, AuthResult.success);
    return service;
  }

  DashboardSummary emptySummary() => DashboardSummary.empty;

  DashboardSummary sampleSummary() => DashboardSummary(
    activeStudents: 5,
    families: 3,
    activeEmployees: 2,
    todayCollection: 1200,
    monthCollection: 24000,
    outstandingFees: 7500,
    monthSalary: 35000,
    monthPendingSalary: 8000,
    monthExpenses: 4100,
    recentPayments: [
      RecentActivityItem(
        title: 'Ali Raza',
        subtitle: 'Payment PAY-000001',
        amount: 1000,
        dateTime: DateTime(2026, 8, 13),
      ),
    ],
    recentAdmissions: [
      RecentActivityItem(
        title: 'Hina',
        subtitle: 'Admission ADM-000001 · Class 5',
        dateTime: DateTime(2026, 8, 12),
      ),
    ],
    recentExpenses: [
      RecentActivityItem(
        title: 'Utilities',
        subtitle: 'Electricity bill',
        amount: 2500,
        dateTime: DateTime(2026, 8, 11),
      ),
    ],
    asOf: DateTime(2026, 8, 14, 10),
  );

  Future<void> pumpDashboard(
    WidgetTester tester,
    DashboardService service,
    AuthService authService,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          authService: authService,
          dashboardService: service,
          familyService: FamilyService(FakeFamilyRepository()),
          studentService: StudentService(
            FakeStudentRepository(familyRepository: FakeFamilyRepository()),
          ),
          feeService: FeeService(
            repository: FakeFeeRepository(),
            authService: authService,
          ),
          importService: buildTestImportService(),
          employeeService: EmployeeService(FakeEmployeeRepository()),
          salaryService: SalaryService(FakeSalaryRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('DashboardScreen', () {
    testWidgets('renders header with user, role, date and logout', (
      tester,
    ) async {
      final authService = await loggedInAuthService();
      await pumpDashboard(
        tester,
        DashboardService(FakeDashboardRepository(summary: sampleSummary())),
        authService,
      );

      expect(find.text('School Office Management System'), findsOneWidget);
      expect(find.text('Welcome, Admin User'), findsOneWidget);
      expect(find.textContaining('School Admin'), findsOneWidget);
      expect(find.textContaining('Fri, 14 Aug 2026'), findsOneWidget);
      expect(find.byKey(const Key('logout_button')), findsOneWidget);
    });

    testWidgets('shows nine stat cards with zero values on empty data', (
      tester,
    ) async {
      final authService = await loggedInAuthService();
      await pumpDashboard(
        tester,
        DashboardService(FakeDashboardRepository(summary: emptySummary())),
        authService,
      );

      for (final label in [
        'Active Students',
        'Families',
        'Active Staff',
        "Today's Collection",
        'This Month Collection',
        'Outstanding Fees',
        'This Month Salary',
        'Pending Salaries',
        'This Month Expenses',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Rs 0'), findsNWidgets(6));
    });

    testWidgets('shows the empty-state panel when there is no data', (
      tester,
    ) async {
      final authService = await loggedInAuthService();
      await pumpDashboard(
        tester,
        DashboardService(FakeDashboardRepository(summary: emptySummary())),
        authService,
      );

      expect(find.text('No records yet'), findsOneWidget);
    });

    testWidgets('renders computed values and recent activity for real data', (
      tester,
    ) async {
      final authService = await loggedInAuthService();
      await pumpDashboard(
        tester,
        DashboardService(FakeDashboardRepository(summary: sampleSummary())),
        authService,
      );

      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Rs 24,000'), findsOneWidget);
      expect(find.text('Rs 7,500'), findsOneWidget);
      expect(find.text('Rs 8,000'), findsOneWidget);
      expect(find.text('No records yet'), findsNothing);
      expect(find.text('Payments'), findsOneWidget);
      expect(find.text('Admissions'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Ali Raza'), findsOneWidget);
      expect(find.text('Hina'), findsOneWidget);
    });

    testWidgets('Add Student quick action opens the student form', (
      tester,
    ) async {
      final authService = await loggedInAuthService();
      await pumpDashboard(
        tester,
        DashboardService(FakeDashboardRepository(summary: emptySummary())),
        authService,
      );

      final quickAction = find.byKey(const Key('quick_add_student'));
      await tester.ensureVisible(quickAction);
      await tester.pumpAndSettle();
      await tester.tap(quickAction);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('student_name')), findsOneWidget);
      expect(find.text('Register student'), findsOneWidget);
    });

    testWidgets('New Admission quick action opens the admission wizard', (
      tester,
    ) async {
      final authService = await loggedInAuthService();
      await pumpDashboard(
        tester,
        DashboardService(FakeDashboardRepository(summary: emptySummary())),
        authService,
      );

      final quickAction = find.byKey(const Key('quick_new_admission'));
      await tester.ensureVisible(quickAction);
      await tester.pumpAndSettle();
      await tester.tap(quickAction);
      await tester.pumpAndSettle();

      expect(find.text('New Admission'), findsOneWidget);
      expect(find.byKey(const Key('adm_family_search')), findsOneWidget);
      expect(find.text('Step 1 of 3 — Existing family'), findsOneWidget);
    });

    testWidgets('Search Student quick action opens the student list', (
      tester,
    ) async {
      final authService = await loggedInAuthService();
      await pumpDashboard(
        tester,
        DashboardService(FakeDashboardRepository(summary: emptySummary())),
        authService,
      );

      final quickAction = find.byKey(const Key('quick_search_student'));
      await tester.ensureVisible(quickAction);
      await tester.pumpAndSettle();
      await tester.tap(quickAction);
      await tester.pumpAndSettle();

      expect(find.text('Student Management'), findsOneWidget);
      expect(find.byKey(const Key('student_search_field')), findsOneWidget);
    });

    testWidgets('Active Students stat card opens the student list', (
      tester,
    ) async {
      final authService = await loggedInAuthService();
      await pumpDashboard(
        tester,
        DashboardService(FakeDashboardRepository(summary: emptySummary())),
        authService,
      );

      await tester.tap(find.text('Active Students'));
      await tester.pumpAndSettle();

      expect(find.text('Student Management'), findsOneWidget);
      expect(find.byKey(const Key('student_search_field')), findsOneWidget);
    });

    testWidgets('Add Family quick action opens the family form', (
      tester,
    ) async {
      final authService = await loggedInAuthService();
      await pumpDashboard(
        tester,
        DashboardService(FakeDashboardRepository(summary: emptySummary())),
        authService,
      );

      final quickAction = find.byKey(const Key('quick_add_family'));
      await tester.ensureVisible(quickAction);
      await tester.pumpAndSettle();
      await tester.tap(quickAction);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('family_guardian')), findsOneWidget);
      expect(find.text('Create family'), findsOneWidget);
    });

    testWidgets('Families stat card opens the family list', (tester) async {
      final authService = await loggedInAuthService();
      await pumpDashboard(
        tester,
        DashboardService(FakeDashboardRepository(summary: emptySummary())),
        authService,
      );

      await tester.tap(find.text('Families'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('family_search_field')), findsOneWidget);
      expect(find.text('Family Management'), findsOneWidget);
    });

    testWidgets('Salaries quick action opens the salary hub', (tester) async {
      final authService = await loggedInAuthService();
      await pumpDashboard(
        tester,
        DashboardService(FakeDashboardRepository(summary: emptySummary())),
        authService,
      );

      final quickAction = find.byKey(const Key('quick_salaries'));
      await tester.ensureVisible(quickAction);
      await tester.pumpAndSettle();
      await tester.tap(quickAction);
      await tester.pumpAndSettle();

      expect(find.text('Salary Management'), findsOneWidget);
      expect(find.byKey(const Key('salary_menu_records')), findsOneWidget);
    });

    testWidgets('Pending Salaries stat opens the salary hub', (tester) async {
      final authService = await loggedInAuthService();
      await pumpDashboard(
        tester,
        DashboardService(FakeDashboardRepository(summary: emptySummary())),
        authService,
      );

      await tester.ensureVisible(find.text('Pending Salaries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pending Salaries'));
      await tester.pumpAndSettle();

      expect(find.text('Salary Management'), findsOneWidget);
    });

    testWidgets('shows error state and recovers via retry', (tester) async {
      final authService = await loggedInAuthService();
      final repository = FakeDashboardRepository(summary: emptySummary())
        ..error = StateError('x');
      final service = DashboardService(repository);
      await pumpDashboard(tester, service, authService);

      expect(find.text('The dashboard could not be loaded.'), findsOneWidget);

      repository.error = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('No records yet'), findsOneWidget);
    });

    testWidgets('logout returns to an unauthenticated state', (tester) async {
      final authService = await loggedInAuthService();
      await pumpDashboard(
        tester,
        DashboardService(FakeDashboardRepository(summary: emptySummary())),
        authService,
      );

      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();

      expect(authService.isAuthenticated, isFalse);
    });
  });
}
