import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/auth/domain/services/auth_service.dart';
import 'package:school_office_management/features/fee/application/fee_service.dart';
import 'package:school_office_management/features/settings/domain/services/settings_service.dart';
import 'package:school_office_management/features/settings/presentation/settings_screen.dart';

import '../fee/fakes/fake_fee_repository.dart';
import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsService> buildSettings({bool admin = true}) async {
    if (admin) return buildTestSettingsService();
    return buildTestSettingsService(
      authService: await buildTestDataEntryAuthService(),
    );
  }

  Future<AuthService> buildAuth({bool admin = true}) =>
      admin ? buildTestAdminAuthService() : buildTestDataEntryAuthService();

  Future<void> pumpScreen(
    WidgetTester tester, {
    required SettingsService settings,
    required AuthService auth,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          settingsService: settings,
          feeService: FeeService(
            repository: FakeFeeRepository(),
            authService: auth,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('rendering', () {
    testWidgets('admin sees all four tabs and the editable profile form', (tester) async {
      useLargeSurface(tester);
      final auth = await buildAuth();
      final settings = await buildSettings();
      await pumpScreen(tester, settings: settings, auth: auth);

      expect(find.text('School Settings'), findsWidgets);
      for (final label in ['Profile', 'Academic', 'Fee', 'Receipt']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byKey(const Key('settings_school_name')), findsOneWidget);
      expect(find.byKey(const Key('settings_save_profile')), findsOneWidget);
      expect(find.byKey(const Key('settings_change_logo')), findsOneWidget);
      expect(find.byType(MaterialBanner), findsNothing);
    });

    testWidgets('data entry user sees the read-only banner and no edit controls',
        (tester) async {
      useLargeSurface(tester);
      final auth = await buildAuth(admin: false);
      final settings = await buildSettings(admin: false);
      await pumpScreen(tester, settings: settings, auth: auth);

      expect(find.textContaining('read-only mode'), findsOneWidget);
      expect(find.byKey(const Key('settings_save_profile')), findsNothing);
      expect(find.byKey(const Key('settings_change_logo')), findsNothing);
      expect(find.byKey(const Key('settings_classs_add')), findsNothing);

      final nameField = tester.widget<TextFormField>(
        find.byKey(const Key('settings_school_name')),
      );
      expect(nameField.enabled, isFalse);
    });

    testWidgets('fee tab shows the fee structures overview', (tester) async {
      useLargeSurface(tester);
      final auth = await buildAuth();
      final settings = await buildSettings();
      await pumpScreen(tester, settings: settings, auth: auth);

      await openTab(tester, 'Fee');
      expect(find.text('Fee structures'), findsOneWidget);
      expect(
        find.byKey(const Key('settings_open_fee_structures')),
        findsOneWidget,
      );
    });
  });

  group('profile tab', () {
    testWidgets('saving a valid profile persists it and shows a snackbar', (tester) async {
      useLargeSurface(tester);
      final auth = await buildAuth();
      final settings = await buildSettings();
      await pumpScreen(tester, settings: settings, auth: auth);

      await tester.enterText(
        find.byKey(const Key('settings_school_name')),
        'Bright Future School',
      );
      await tester.enterText(
        find.byKey(const Key('settings_phone')),
        '0300-1234567',
      );
      await tester.tap(find.byKey(const Key('settings_save_profile')));
      await tester.pumpAndSettle();

      expect(find.text('Profile saved.'), findsOneWidget);
      expect(settings.profile.schoolName, 'Bright Future School');
      expect(settings.profile.phone, '0300-1234567');
    });
  });

  group('academic tab', () {
    testWidgets('seeded classes are listed and a new class can be added', (tester) async {
      useLargeSurface(tester);
      final auth = await buildAuth();
      final settings = await buildSettings();
      await pumpScreen(tester, settings: settings, auth: auth);

      await openTab(tester, 'Academic');
      expect(find.text('Play Group'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings_classs_add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('settings_add_class_name')),
        'Six',
      );
      await tester.tap(find.byKey(const Key('settings_add_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Class added.'), findsOneWidget);
      expect(
        settings.allClasses.any((c) => c.className == 'Six'),
        isTrue,
      );
    });

    testWidgets('a class with no students can be deactivated', (tester) async {
      useLargeSurface(tester);
      final auth = await buildAuth();
      final settings = await buildSettings();
      await pumpScreen(tester, settings: settings, auth: auth);

      final class5 = settings.allClasses.firstWhere((c) => c.className == '5');
      await openTab(tester, 'Academic');
      await tester.ensureVisible(
        find.byKey(Key('settings_classs_toggle_${class5.id}')),
      );
      await tester.tap(
        find.byKey(Key('settings_classs_toggle_${class5.id}')),
      );
      await tester.pumpAndSettle();

      expect(find.text('5 deactivated.'), findsOneWidget);
      expect(
        settings.allClasses.firstWhere((c) => c.id == class5.id).isActive,
        isFalse,
      );
    });

    testWidgets('duplicate class names show an error snackbar', (tester) async {
      useLargeSurface(tester);
      final auth = await buildAuth();
      final settings = await buildSettings();
      await pumpScreen(tester, settings: settings, auth: auth);

      await openTab(tester, 'Academic');
      await tester.tap(find.byKey(const Key('settings_classs_add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('settings_add_class_name')),
        'Play Group',
      );
      await tester.tap(find.byKey(const Key('settings_add_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Class "Play Group" already exists.'), findsOneWidget);
    });
  });

  group('receipt tab', () {
    testWidgets('saving a footer persists it and shows a snackbar', (tester) async {
      useLargeSurface(tester);
      final auth = await buildAuth();
      final settings = await buildSettings();
      await settings.saveProfile(schoolName: 'Bright Future School');
      await pumpScreen(tester, settings: settings, auth: auth);

      await openTab(tester, 'Receipt');
      await tester.enterText(
        find.byKey(const Key('settings_receipt_footer')),
        'Account: 0001-2345',
      );
      await tester.tap(find.byKey(const Key('settings_save_receipt_footer')));
      await tester.pumpAndSettle();

      expect(find.text('Receipt footer saved.'), findsOneWidget);
      expect(settings.profile.receiptFooter, 'Account: 0001-2345');
    });
  });
}
