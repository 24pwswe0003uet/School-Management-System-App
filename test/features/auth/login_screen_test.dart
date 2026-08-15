import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/auth/domain/entities/app_role.dart';
import 'package:school_office_management/features/auth/domain/entities/app_user.dart';
import 'package:school_office_management/features/auth/domain/repositories/auth_repository.dart';
import 'package:school_office_management/features/auth/domain/services/auth_service.dart';
import 'package:school_office_management/features/auth/presentation/auth_gate.dart';
import 'package:school_office_management/features/auth/presentation/login_screen.dart';
import 'package:school_office_management/features/dashboard/domain/services/dashboard_service.dart';
import 'package:school_office_management/features/employee/domain/services/employee_service.dart';
import 'package:school_office_management/features/family/domain/services/family_service.dart';
import 'package:school_office_management/features/fee/application/fee_service.dart';
import 'package:school_office_management/features/import/application/import_service.dart';
import 'package:school_office_management/features/salary/domain/services/salary_service.dart';
import 'package:school_office_management/features/student/domain/services/student_service.dart';

import '../dashboard/fakes/fake_dashboard_repository.dart';
import '../employee/fakes/fake_employee_repository.dart';
import '../family/fakes/fake_family_repository.dart';
import '../fee/fakes/fake_fee_repository.dart';
import '../import/fakes/fake_import_repository.dart';
import '../salary/fakes/fake_salary_repository.dart';
import '../student/fakes/fake_student_repository.dart';

class FakeAuthRepository implements AuthRepository {
  final Map<String, String> passwords = {};
  bool failAuthenticate = false;

  @override
  Future<AppUser?> authenticate(String identifier, String password) async {
    if (failAuthenticate) throw Exception('simulated database failure');
    final key = identifier.trim().toLowerCase();
    if (passwords[key] != password) return null;
    return AppUser(
      id: 1,
      username: identifier.trim(),
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
    passwords[username.trim().toLowerCase()] = password;
    return AppUser(
      id: 1,
      username: username.trim(),
      displayName: displayName.trim(),
      role: role,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<bool> hasAnyUser() async => passwords.isNotEmpty;
}

void main() {
  Future<AuthService> serviceWithAdmin() async {
    final repository = FakeAuthRepository()
      ..passwords['admin'] = 'CorrectPass123';
    final service = AuthService(repository);
    await service.refreshSetupStatus();
    return service;
  }

  DashboardService dashboardService() =>
      DashboardService(FakeDashboardRepository());

  FamilyService familyService() => FamilyService(FakeFamilyRepository());

  StudentService studentService() => StudentService(
    FakeStudentRepository(familyRepository: FakeFamilyRepository()),
  );

  FeeService feeService() => FeeService(
    repository: FakeFeeRepository(),
    authService: AuthService(FakeAuthRepository()),
  );

  ImportService importService() => buildTestImportService();

  EmployeeService employeeService() =>
      EmployeeService(FakeEmployeeRepository());

  SalaryService salaryService() => SalaryService(FakeSalaryRepository());

  Future<void> pumpLogin(WidgetTester tester, AuthService service) {
    return tester.pumpWidget(
      MaterialApp(home: LoginScreen(authService: service)),
    );
  }

  /// Scrolls a (possibly off-screen) widget into view and taps it, so the
  /// setup form works even on small test surfaces.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> submitLogin(
    WidgetTester tester, {
    String username = 'admin',
    String password = 'CorrectPass123',
  }) async {
    await tester.enterText(find.byKey(const Key('login_username')), username);
    await tester.enterText(find.byKey(const Key('login_password')), password);
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
  }

  group('LoginScreen', () {
    testWidgets('renders branding, fields and login button', (tester) async {
      await pumpLogin(tester, await serviceWithAdmin());

      expect(find.text('School Office Management System'), findsOneWidget);
      expect(find.byKey(const Key('login_username')), findsOneWidget);
      expect(find.byKey(const Key('login_password')), findsOneWidget);
      expect(find.byKey(const Key('login_submit')), findsOneWidget);
    });

    testWidgets(
      '4. empty fields show validation messages and do not call repo',
      (tester) async {
        final service = await serviceWithAdmin();
        await pumpLogin(tester, service);

        await tester.tap(find.byKey(const Key('login_submit')));
        await tester.pumpAndSettle();

        expect(
          find.text('Please enter your username or email.'),
          findsOneWidget,
        );
        expect(find.text('Please enter your password.'), findsOneWidget);
      },
    );

    testWidgets('3. unknown account shows a generic error', (tester) async {
      await pumpLogin(tester, await serviceWithAdmin());

      await submitLogin(tester, username: 'nobody');

      expect(find.text('Invalid username or password.'), findsOneWidget);
      expect(find.byKey(const Key('login_username')), findsOneWidget);
    });

    testWidgets('2. wrong password shows a generic error', (tester) async {
      await pumpLogin(tester, await serviceWithAdmin());

      await submitLogin(tester, password: 'WrongPass');

      expect(find.text('Invalid username or password.'), findsOneWidget);
    });

    testWidgets('8. database error shows a neutral message', (tester) async {
      final repository = FakeAuthRepository()
        ..passwords['admin'] = 'CorrectPass123'
        ..failAuthenticate = true;
      final service = AuthService(repository);
      await service.refreshSetupStatus();
      await pumpLogin(tester, service);

      await submitLogin(tester);

      expect(
        find.text(
          'Could not access local data. Please check the installation and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('show/hide password toggle toggles obscurity', (tester) async {
      await pumpLogin(tester, await serviceWithAdmin());

      Finder editableFinder() => find.descendant(
        of: find.byKey(const Key('login_password')),
        matching: find.byType(EditableText),
      );

      expect(tester.widget<EditableText>(editableFinder()).obscureText, isTrue);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(editableFinder()).obscureText,
        isFalse,
      );
    });
  });

  group('AuthGate full flow', () {
    testWidgets('1+6. login opens dashboard, logout returns to login', (
      tester,
    ) async {
      final service = await serviceWithAdmin();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authService: service,
            dashboardService: dashboardService(),
            familyService: familyService(),
            studentService: studentService(),
            feeService: feeService(),
            importService: importService(),
            employeeService: employeeService(),
            salaryService: salaryService(),
          ),
        ),
      );

      await submitLogin(tester);
      expect(find.textContaining('Welcome, Admin User'), findsOneWidget);

      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_username')), findsOneWidget);
      expect(service.isAuthenticated, isFalse);
    });

    testWidgets('first-run setup creates admin then shows login', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      final service = AuthService(repository);
      await service.refreshSetupStatus();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authService: service,
            dashboardService: dashboardService(),
            familyService: familyService(),
            studentService: studentService(),
            feeService: feeService(),
            importService: importService(),
            employeeService: employeeService(),
            salaryService: salaryService(),
          ),
        ),
      );

      // No account yet -> setup screen.
      expect(find.text('Set up your school account'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('setup_display_name')),
        'Head Master',
      );
      await tester.enterText(
        find.byKey(const Key('setup_username')),
        'headmaster',
      );
      await tester.enterText(
        find.byKey(const Key('setup_password')),
        'StrongPass1',
      );
      await tester.enterText(
        find.byKey(const Key('setup_confirm')),
        'StrongPass1',
      );
      await tapVisible(tester, find.byKey(const Key('setup_submit')));

      // Success dialog, then continue -> login screen.
      expect(find.text('Account created'), findsOneWidget);
      await tester.tap(find.text('Continue to login'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_username')), findsOneWidget);
    });

    testWidgets('setup validation blocks empty and mismatched passwords', (
      tester,
    ) async {
      final service = AuthService(FakeAuthRepository());
      await service.refreshSetupStatus();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authService: service,
            dashboardService: dashboardService(),
            familyService: familyService(),
            studentService: studentService(),
            feeService: feeService(),
            importService: importService(),
            employeeService: employeeService(),
            salaryService: salaryService(),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('setup_password')), 'abc');
      await tester.enterText(
        find.byKey(const Key('setup_confirm')),
        'different',
      );
      await tapVisible(tester, find.byKey(const Key('setup_submit')));

      expect(find.textContaining('at least 6 characters'), findsOneWidget);
      expect(find.text('Passwords do not match.'), findsOneWidget);
    });
  });
}
