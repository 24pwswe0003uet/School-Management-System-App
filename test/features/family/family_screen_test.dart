import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/family/domain/entities/family.dart';
import 'package:school_office_management/features/family/domain/entities/family_student.dart';
import 'package:school_office_management/features/family/domain/services/family_service.dart';
import 'package:school_office_management/features/family/presentation/family_details_screen.dart';
import 'package:school_office_management/features/family/presentation/family_form_screen.dart';
import 'package:school_office_management/features/family/presentation/family_list_screen.dart';
import 'package:school_office_management/features/student/domain/services/student_service.dart';

import '../settings/helpers.dart';
import '../student/fakes/fake_student_repository.dart';
import 'fakes/fake_family_repository.dart';

Family buildFamily({
  int id = 1,
  String familyId = 'FAM-000001',
  String guardianName = 'Ahmed Khan',
  String? motherName = 'Sara Khan',
  String? primaryPhone = '0300-1234567',
  String? secondaryPhone,
  String? address = 'House 4, Main Street',
  String? cnic,
  String? notes,
  FamilyStatus status = FamilyStatus.active,
}) {
  return Family(
    id: id,
    familyId: familyId,
    guardianName: guardianName,
    motherName: motherName,
    primaryPhone: primaryPhone,
    secondaryPhone: secondaryPhone,
    address: address,
    cnic: cnic,
    notes: notes,
    status: status,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );
}

FamilyService serviceWith(List<Family> families) =>
    FamilyService(FakeFamilyRepository(families: families));

/// Unused by the family tests but required to construct the screens; the
/// student service backs the "add another child" navigation.
StudentService studentService() => StudentService(
  FakeStudentRepository(familyRepository: FakeFamilyRepository()),
);

Widget wrap(Widget child) => MaterialApp(home: child);

/// Gives the details screen enough room that the lazy ListView builds every
/// row (the test font is much wider than a real font).
void useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> pumpList(WidgetTester tester, FamilyService service) async {
  final settingsService = await buildTestSettingsService();
  await tester.pumpWidget(
    wrap(
      FamilyListScreen(
        familyService: service,
        studentService: studentService(),
        settingsService: settingsService,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pushes the family form and returns a growable holder that receives the
/// popped result once the form is saved and popped.
Future<List<Family?>> pushAndOpen(
  WidgetTester tester,
  FamilyService service, {
  Family? existing,
}) async {
  final result = <Family?>[];
  final settingsService = await buildTestSettingsService();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result.add(
                  await Navigator.of(context).push<Family>(
                    MaterialPageRoute(
                      builder: (_) => FamilyFormScreen(
                        familyService: service,
                        studentService: studentService(),
                        settingsService: settingsService,
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

/// Fills the guardian field (when given) and taps Save using fixed pumps —
/// `pumpAndSettle` cannot be used because the loading spinner animates while
/// the duplicate-warning dialog is open.
Future<void> submitForm(WidgetTester tester, {String? guardian}) async {
  if (guardian != null) {
    await tester.enterText(find.byKey(const Key('family_guardian')), guardian);
  }
  final save = find.byKey(const Key('family_save'));
  await tester.ensureVisible(save);
  await tester.pump();
  await tester.tap(save);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  group('FamilyListScreen', () {
    testWidgets('lists families with IDs and guardian names', (tester) async {
      final service = serviceWith([
        buildFamily(),
        buildFamily(
          id: 2,
          familyId: 'FAM-000002',
          guardianName: 'Usman Ali',
          primaryPhone: '0300-9999999',
        ),
      ]);
      await pumpList(tester, service);

      expect(find.text('FAM-000001'), findsOneWidget);
      expect(find.text('Ahmed Khan'), findsOneWidget);
      expect(find.text('FAM-000002'), findsOneWidget);
      expect(find.text('Usman Ali'), findsOneWidget);
    });

    testWidgets('shows an empty state when there are no families', (
      tester,
    ) async {
      await pumpList(tester, serviceWith([]));

      expect(find.text('No families found yet.'), findsOneWidget);
      expect(
        find.text('Use "Add Family" to create the first record.'),
        findsOneWidget,
      );
    });

    testWidgets('search filters the family list', (tester) async {
      final service = serviceWith([
        buildFamily(),
        buildFamily(id: 2, familyId: 'FAM-000002', guardianName: 'Usman Ali'),
      ]);
      await pumpList(tester, service);

      await tester.enterText(
        find.byKey(const Key('family_search_field')),
        'usman',
      );
      await tester.pumpAndSettle();

      expect(find.text('Usman Ali'), findsOneWidget);
      expect(find.text('Ahmed Khan'), findsNothing);
    });

    testWidgets('search matches a family ID', (tester) async {
      final service = serviceWith([buildFamily()]);
      await pumpList(tester, service);

      await tester.enterText(
        find.byKey(const Key('family_search_field')),
        'FAM-000001',
      );
      await tester.pumpAndSettle();

      expect(find.text('Ahmed Khan'), findsOneWidget);
    });

    testWidgets('shows an error state and recovers via retry', (tester) async {
      final repository = FakeFamilyRepository(families: [buildFamily()]);
      repository.failSearch = true;
      final service = FamilyService(repository);
      await pumpList(tester, service);

      expect(find.text('Families could not be loaded.'), findsOneWidget);

      repository.failSearch = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Ahmed Khan'), findsOneWidget);
    });

    testWidgets('opens the create form via the FAB', (tester) async {
      final service = serviceWith([]);
      await pumpList(tester, service);

      await tester.tap(find.byKey(const Key('family_add_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Add Family'), findsWidgets);
      expect(find.byKey(const Key('family_guardian')), findsOneWidget);
      expect(find.text('FAM-000001'), findsOneWidget);
      expect(find.text('Create family'), findsOneWidget);
    });

    testWidgets('tapping a family card opens its details', (tester) async {
      final service = serviceWith([buildFamily()]);
      await pumpList(tester, service);

      await tester.tap(find.text('Ahmed Khan'));
      await tester.pumpAndSettle();

      expect(find.text('Family Details'), findsOneWidget);
      expect(find.text('FAM-000001'), findsWidgets);
    });
  });

  group('FamilyFormScreen', () {
    testWidgets('validates required and malformed fields', (tester) async {
      useLargeSurface(tester);
      final service = serviceWith([]);
      await pushAndOpen(tester, service);

      await tester.enterText(
        find.byKey(const Key('family_phone')),
        'not a phone',
      );
      await tester.enterText(find.byKey(const Key('family_cnic')), '123');
      await submitForm(tester);

      expect(
        find.text('Please enter the father/guardian name.'),
        findsOneWidget,
      );
      expect(
        find.text('Phone can only contain digits, spaces, + or -.'),
        findsOneWidget,
      );
      expect(find.text('CNIC must be exactly 13 digits.'), findsOneWidget);
      expect(find.text('FAM-000001'), findsOneWidget);
    });

    testWidgets('creates a family and pops with the result', (tester) async {
      useLargeSurface(tester);
      final service = serviceWith([]);
      final result = await pushAndOpen(tester, service);

      await tester.enterText(
        find.byKey(const Key('family_guardian')),
        'Usman Ali',
      );
      await tester.enterText(
        find.byKey(const Key('family_phone')),
        '0300-5555555',
      );
      await submitForm(tester);

      expect(result.single?.guardianName, 'Usman Ali');
      expect(result.single?.familyId, 'FAM-000001');
    });

    testWidgets('duplicate warning Cancel aborts the save', (tester) async {
      useLargeSurface(tester);
      final repository = FakeFamilyRepository(
        families: [
          buildFamily(guardianName: 'Ahmed Khan', primaryPhone: '0300-1234567'),
        ],
      );
      final service = FamilyService(repository);
      await pushAndOpen(tester, service);

      await tester.enterText(
        find.byKey(const Key('family_guardian')),
        'Ahmed Khan',
      );
      await tester.enterText(
        find.byKey(const Key('family_phone')),
        '0300-1234567',
      );
      await submitForm(tester);

      expect(find.text('Possible existing families'), findsOneWidget);
      expect(find.byKey(const Key('dup_FAM-000001')), findsOneWidget);

      await tester.tap(find.byKey(const Key('dup_cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Possible existing families'), findsNothing);
      expect(repository.all, hasLength(1));
      expect(find.text('Add Family'), findsWidgets);
    });

    testWidgets('Create anyway saves a second family', (tester) async {
      useLargeSurface(tester);
      final service = serviceWith([
        buildFamily(guardianName: 'Ahmed Khan', primaryPhone: '0300-1234567'),
      ]);
      final result = await pushAndOpen(tester, service);

      await tester.enterText(
        find.byKey(const Key('family_guardian')),
        'Ahmed Khan',
      );
      await tester.enterText(
        find.byKey(const Key('family_phone')),
        '0300-1234567',
      );
      await submitForm(tester);

      await tester.tap(find.byKey(const Key('dup_create_anyway')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(result.single?.familyId, 'FAM-000002');
    });

    testWidgets('View opens the matched family profile', (tester) async {
      useLargeSurface(tester);
      final service = serviceWith([
        buildFamily(guardianName: 'Ahmed Khan', primaryPhone: '0300-1234567'),
      ]);
      await pushAndOpen(tester, service);

      await tester.enterText(
        find.byKey(const Key('family_guardian')),
        'Ahmed Khan',
      );
      await submitForm(tester);

      await tester.tap(find.byKey(const Key('dup_FAM-000001')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Family Details'), findsOneWidget);
      expect(find.text('Ahmed Khan'), findsWidgets);
    });

    testWidgets('edit mode prefills values and saves changes', (tester) async {
      useLargeSurface(tester);
      final service = serviceWith([buildFamily()]);
      final result = await pushAndOpen(
        tester,
        service,
        existing: buildFamily(),
      );

      expect(find.text('Edit Family'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Ahmed Khan'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('family_guardian')),
        'New Guardian',
      );
      await submitForm(tester);

      expect(result.single?.guardianName, 'New Guardian');
      expect(result.single?.familyId, 'FAM-000001');
    });
  });

  group('FamilyDetailsScreen', () {
    Future<void> pumpDetails(
      WidgetTester tester,
      FamilyService service,
      int familyId,
    ) async {
      await tester.pumpWidget(
        wrap(
          FamilyDetailsScreen(
            familyService: service,
            studentService: studentService(),
            settingsService: await buildTestSettingsService(),
            familyId: familyId,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows family info, students and outstanding fees', (
      tester,
    ) async {
      useLargeSurface(tester);
      final family = buildFamily();
      final repository = FakeFamilyRepository(families: [family]);
      repository.seedStudents(family.id, [
        const FamilyStudent(
          id: 1,
          studentId: 'STU-000001',
          name: 'Ali Khan',
          className: '5',
          section: 'A',
          status: 'active',
        ),
        const FamilyStudent(
          id: 2,
          studentId: 'STU-000002',
          name: 'Usman Khan',
          className: '3',
          section: 'B',
          status: 'active',
        ),
      ]);
      repository.seedOutstanding(family.id, 12500);
      await pumpDetails(tester, FamilyService(repository), family.id);

      expect(find.text('Family Details'), findsOneWidget);
      expect(find.text('FAM-000001'), findsOneWidget);
      expect(find.text('Ahmed Khan'), findsWidgets);
      expect(find.text('Sara Khan'), findsOneWidget);
      expect(find.text('0300-1234567'), findsOneWidget);
      expect(find.text('House 4, Main Street'), findsOneWidget);
      expect(find.text('Students (2)'), findsOneWidget);
      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('Usman Khan'), findsOneWidget);
      expect(find.textContaining('5'), findsOneWidget);
      expect(find.text('Rs 12,500'), findsOneWidget);
    });

    testWidgets('add another child opens the student form preselected', (
      tester,
    ) async {
      useLargeSurface(tester);
      final family = buildFamily();
      await pumpDetails(tester, serviceWith([family]), family.id);

      await tester.tap(find.byKey(const Key('family_add_child')));
      await tester.pumpAndSettle();

      expect(find.text('Add Student'), findsWidgets);
      expect(find.text('FAM-000001'), findsOneWidget);
      expect(find.byKey(const Key('student_change_family')), findsOneWidget);
    });

    testWidgets('archive and unarchive toggle the status', (tester) async {
      useLargeSurface(tester);
      final family = buildFamily();
      await pumpDetails(tester, serviceWith([family]), family.id);

      expect(find.text('Active'), findsWidgets);
      await tester.tap(find.byKey(const Key('family_archive')));
      await tester.pumpAndSettle();

      expect(find.text('Archived'), findsWidgets);
      expect(find.text('Unarchive'), findsOneWidget);

      await tester.tap(find.byKey(const Key('family_archive')));
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsWidgets);
    });

    testWidgets('delete is blocked when students exist, archive offered', (
      tester,
    ) async {
      useLargeSurface(tester);
      final family = buildFamily();
      final repository = FakeFamilyRepository(families: [family]);
      repository.seedStudents(family.id, const [
        FamilyStudent(
          id: 1,
          studentId: 'STU-000001',
          name: 'Ali Khan',
          className: '5',
          section: 'A',
          status: 'active',
        ),
      ]);
      await pumpDetails(tester, FamilyService(repository), family.id);

      await tester.tap(find.byKey(const Key('family_delete')));
      await tester.pumpAndSettle();

      expect(find.text('Family cannot be deleted'), findsOneWidget);
      expect(
        find.textContaining('Families with students are never deleted'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('family_archive_from_delete')));
      await tester.pumpAndSettle();

      expect(find.text('Archived'), findsWidgets);
      expect(repository.all.single.status, FamilyStatus.inactive);
    });

    testWidgets('deleting an empty family confirms and pops', (tester) async {
      useLargeSurface(tester);
      final family = buildFamily();
      final repository = FakeFamilyRepository(families: [family]);
      final service = FamilyService(repository);
      final settingsService = await buildTestSettingsService();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FamilyDetailsScreen(
                          familyService: service,
                          studentService: studentService(),
                          settingsService: settingsService,
                          familyId: family.id,
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

      await tester.tap(find.byKey(const Key('family_delete')));
      await tester.pumpAndSettle();

      expect(find.text('Delete family?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('family_delete_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Family Details'), findsNothing);
      expect(repository.all, isEmpty);
    });

    testWidgets('edit opens the prefilled form and details refresh', (
      tester,
    ) async {
      useLargeSurface(tester);
      final family = buildFamily();
      final service = serviceWith([family]);
      await pumpDetails(tester, service, family.id);

      await tester.tap(find.byKey(const Key('family_edit')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Family'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('family_guardian')),
        'Updated Name',
      );
      final save = find.byKey(const Key('family_save'));
      await tester.ensureVisible(save);
      await tester.pump();
      await tester.tap(save);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Family Details'), findsOneWidget);
      expect(find.text('Updated Name'), findsWidgets);
    });
  });
}
