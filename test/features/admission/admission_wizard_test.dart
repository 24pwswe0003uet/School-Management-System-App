import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/admission/presentation/admission_wizard_screen.dart';
import 'package:school_office_management/features/family/domain/entities/family.dart';
import 'package:school_office_management/features/family/domain/services/family_service.dart';
import 'package:school_office_management/features/student/domain/entities/student.dart';
import 'package:school_office_management/features/student/domain/services/student_service.dart';

import '../family/fakes/fake_family_repository.dart';
import '../student/fakes/fake_student_repository.dart';

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
    status: FamilyStatus.active,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );
}

Student buildStudent({
  int id = 1,
  String studentId = 'STU-000001',
  int familyId = 1,
  String name = 'Ali Khan',
  StudentGender? gender = StudentGender.male,
  DateTime? dateOfBirth,
  String? admissionNumber,
  DateTime? admissionDate,
  String? className = 'Class 5',
  String? section = 'A',
  StudentStatus status = StudentStatus.active,
}) {
  return Student(
    id: id,
    studentId: studentId,
    familyId: familyId,
    name: name,
    gender: gender,
    dateOfBirth: dateOfBirth ?? DateTime(2020, 8, 1),
    admissionNumber: admissionNumber,
    admissionDate: admissionDate ?? DateTime(2026, 8, 1),
    className: className,
    section: section,
    contactReference: null,
    notes: null,
    status: status,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );
}

({
  FakeFamilyRepository familyRepo,
  FakeStudentRepository studentRepo,
  FamilyService familyService,
  StudentService studentService,
})
servicesWith({List<Family>? families, List<Student>? students}) {
  final familyRepo = FakeFamilyRepository(
    families: families ?? [buildFamily()],
  );
  final studentRepo = FakeStudentRepository(
    students: students ?? const [],
    familyRepository: familyRepo,
  );
  return (
    familyRepo: familyRepo,
    studentRepo: studentRepo,
    familyService: FamilyService(familyRepo),
    studentService: StudentService(studentRepo),
  );
}

Widget wrap(Widget child) => MaterialApp(home: child);

void useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

String todayIso() {
  final now = DateTime.now();
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

Future<void> pumpWizard(
  WidgetTester tester, {
  required StudentService studentService,
  required FamilyService familyService,
}) async {
  await tester.pumpWidget(
    wrap(
      AdmissionWizardScreen(
        studentService: studentService,
        familyService: familyService,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pushes the wizard from a host screen so "Return to Dashboard" can pop back
/// to a real route.
Future<void> pushWizard(
  WidgetTester tester, {
  required StudentService studentService,
  required FamilyService familyService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdmissionWizardScreen(
                    studentService: studentService,
                    familyService: familyService,
                  ),
                ),
              ),
              child: const Text('open wizard'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open wizard'));
  await tester.pumpAndSettle();
}

Future<void> selectFamily(WidgetTester tester, String familyId) async {
  final tile = find.byKey(ValueKey('adm_family_pick_$familyId'));
  await tester.ensureVisible(tile);
  await tester.pump();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> createFamily(
  WidgetTester tester, {
  String guardian = 'Ahmed Khan',
}) async {
  await tester.tap(find.byKey(const Key('adm_create_family')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('family_guardian')), guardian);
  final save = find.byKey(const Key('family_save'));
  await tester.ensureVisible(save);
  await tester.pump();
  await tester.tap(save);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> goToDetails(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('adm_family_next')));
  await tester.pumpAndSettle();
}

Future<void> fillDetails(
  WidgetTester tester, {
  String name = 'Ali Khan',
  String? admissionNumber,
  String className = 'Class 5',
  String section = 'A',
  String fee = '5000',
  String notes = '',
}) async {
  await tester.enterText(find.byKey(const Key('adm_name')), name);
  if (admissionNumber != null) {
    await tester.enterText(
      find.byKey(const Key('adm_admission_number')),
      admissionNumber,
    );
  }
  await tester.enterText(find.byKey(const Key('adm_class')), className);
  await tester.enterText(find.byKey(const Key('adm_section')), section);
  await tester.enterText(find.byKey(const Key('adm_fee')), fee);
  if (notes.isNotEmpty) {
    await tester.enterText(find.byKey(const Key('adm_notes')), notes);
  }
}

Future<void> continueToReview(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('adm_details_continue')));
  await tester.pumpAndSettle();
}

Future<void> confirmAdmission(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('adm_confirm')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  group('AdmissionWizardScreen', () {
    testWidgets('new family admission creates the family, student and record', (
      tester,
    ) async {
      useLargeSurface(tester);
      final services = servicesWith(families: []);
      await pumpWizard(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
      );

      expect(find.text('No family exists yet.'), findsOneWidget);

      await createFamily(tester, guardian: 'Ahmed Khan');
      expect(find.byKey(const Key('adm_change_family')), findsOneWidget);
      expect(find.text('FAM-000001'), findsOneWidget);

      await goToDetails(tester);
      expect(find.byKey(const Key('adm_name')), findsOneWidget);
      await fillDetails(tester);
      await continueToReview(tester);

      expect(find.text('Step 3 of 3 — Review & confirm'), findsOneWidget);
      expect(find.text('Class 5'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('ADM-000001'), findsOneWidget);
      expect(find.text('Rs 5,000'), findsOneWidget);

      await confirmAdmission(tester);

      expect(find.text('Admission saved'), findsOneWidget);
      expect(services.familyRepo.all, hasLength(1));
      expect(services.familyRepo.all.single.guardianName, 'Ahmed Khan');
      expect(services.studentRepo.all, hasLength(1));
      expect(services.studentRepo.all.single.name, 'Ali Khan');
      expect(services.studentRepo.all.single.familyId, 1000);
    });

    testWidgets('existing family admission shows the review and saves', (
      tester,
    ) async {
      useLargeSurface(tester);
      final services = servicesWith();
      await pumpWizard(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
      );

      await selectFamily(tester, 'FAM-000001');
      await goToDetails(tester);
      await fillDetails(tester, name: 'Sara Khan');
      await continueToReview(tester);

      // Review screen shows every planned field. Family and student rows join
      // several values into a single Text, so match with textContaining.
      expect(find.textContaining('FAM-000001'), findsOneWidget);
      expect(find.textContaining('Ahmed Khan'), findsOneWidget);
      expect(find.textContaining('Sara Khan'), findsOneWidget);
      expect(find.text('Class 5'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text(todayIso()), findsOneWidget);
      expect(find.text('ADM-000001'), findsOneWidget);
      expect(find.text('Rs 5,000'), findsOneWidget);

      await confirmAdmission(tester);

      expect(find.text('Admission saved'), findsOneWidget);
      final saved = services.studentRepo.all.single;
      expect(saved.name, 'Sara Khan');
      expect(saved.familyId, 1);

      final details = await services.studentService.getStudentDetails(saved.id);
      expect(details.admissions, hasLength(1));
      expect(details.admissions.single.admissionNumber, 'ADM-000001');
      expect(details.admissions.single.admissionFee, 5000);
      expect(details.admissions.single.className, 'Class 5');
    });

    testWidgets(
      'a duplicate admission number is flagged and can block the save',
      (tester) async {
        useLargeSurface(tester);
        final services = servicesWith(
          students: [buildStudent(admissionNumber: 'ADM-000001')],
        );
        await pumpWizard(
          tester,
          studentService: services.studentService,
          familyService: services.familyService,
        );

        await selectFamily(tester, 'FAM-000001');
        await goToDetails(tester);

        // The number is pre-filled with the next generated id, which is already
        // used by the existing student.
        await fillDetails(tester, name: 'Zain Ali');
        await continueToReview(tester);

        expect(find.text('Possible existing students'), findsOneWidget);
        expect(find.byKey(const Key('adm_dup_STU-000001')), findsOneWidget);

        await tester.tap(find.byKey(const Key('adm_dup_cancel')));
        await tester.pumpAndSettle();

        // Nothing was saved and the operator is still on the details step.
        expect(find.byKey(const Key('adm_name')), findsOneWidget);
        expect(services.studentRepo.all, hasLength(1));

        // Correcting the admission number lets the admission proceed.
        await tester.enterText(
          find.byKey(const Key('adm_admission_number')),
          'ADM-2026-002',
        );
        await continueToReview(tester);
        expect(find.text('Step 3 of 3 — Review & confirm'), findsOneWidget);

        await confirmAdmission(tester);
        expect(find.text('Admission saved'), findsOneWidget);
        expect(services.studentRepo.all, hasLength(2));
      },
    );

    testWidgets(
      'continuing anyway with a used admission number is rejected on save',
      (tester) async {
        useLargeSurface(tester);
        final services = servicesWith(
          students: [buildStudent(admissionNumber: 'ADM-000001')],
        );
        await pumpWizard(
          tester,
          studentService: services.studentService,
          familyService: services.familyService,
        );

        await selectFamily(tester, 'FAM-000001');
        await goToDetails(tester);
        await fillDetails(tester, name: 'Zain Ali');
        await continueToReview(tester);

        await tester.tap(find.byKey(const Key('adm_dup_continue')));
        await tester.pumpAndSettle();
        expect(find.text('Step 3 of 3 — Review & confirm'), findsOneWidget);

        await confirmAdmission(tester);
        expect(
          find.text('Could not save the admission. Please try again.'),
          findsOneWidget,
        );
        expect(services.studentRepo.all, hasLength(1));
      },
    );

    testWidgets(
      'a same-name candidate in the same family is warned but can be admitted',
      (tester) async {
        useLargeSurface(tester);
        final services = servicesWith(students: [buildStudent()]);
        await pumpWizard(
          tester,
          studentService: services.studentService,
          familyService: services.familyService,
        );

        await selectFamily(tester, 'FAM-000001');
        await goToDetails(tester);
        await fillDetails(tester, name: 'Ali Khan');
        await continueToReview(tester);

        expect(find.text('Possible existing students'), findsOneWidget);
        expect(find.byKey(const Key('adm_dup_STU-000001')), findsOneWidget);

        await tester.tap(find.byKey(const Key('adm_dup_continue')));
        await tester.pumpAndSettle();

        await confirmAdmission(tester);
        expect(find.text('Admission saved'), findsOneWidget);
        expect(services.studentRepo.all, hasLength(2));
      },
    );

    testWidgets('invalid required fields block the review step', (
      tester,
    ) async {
      useLargeSurface(tester);
      final services = servicesWith();
      await pumpWizard(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
      );

      await selectFamily(tester, 'FAM-000001');
      await goToDetails(tester);

      // Empty name and a non-numeric fee.
      await tester.enterText(find.byKey(const Key('adm_fee')), 'abc');
      await continueToReview(tester);

      expect(find.text('Please enter the student full name.'), findsOneWidget);
      expect(find.text('Enter a valid amount (0 or more).'), findsOneWidget);
      expect(find.text('Step 2 of 3 — Student details'), findsOneWidget);
      expect(services.studentRepo.all, isEmpty);
    });

    testWidgets('a failed save stays on the review with an error', (
      tester,
    ) async {
      useLargeSurface(tester);
      final services = servicesWith();
      services.studentRepo.failCreate = true;
      await pumpWizard(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
      );

      await selectFamily(tester, 'FAM-000001');
      await goToDetails(tester);
      await fillDetails(tester);
      await continueToReview(tester);
      await confirmAdmission(tester);

      expect(
        find.text('Could not save the admission. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Step 3 of 3 — Review & confirm'), findsOneWidget);
      expect(services.studentRepo.all, isEmpty);
    });

    testWidgets('success screen opens the student profile', (tester) async {
      useLargeSurface(tester);
      final services = servicesWith();
      await pumpWizard(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
      );

      await selectFamily(tester, 'FAM-000001');
      await goToDetails(tester);
      await fillDetails(tester);
      await continueToReview(tester);
      await confirmAdmission(tester);

      expect(find.text('Admission saved'), findsOneWidget);
      expect(find.text('STU-000001'), findsWidgets);

      await tester.tap(find.byKey(const Key('adm_success_open_student')));
      await tester.pumpAndSettle();
      expect(find.text('Student Details'), findsOneWidget);
      expect(find.text('Ali Khan'), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Admission saved'), findsOneWidget);
    });

    testWidgets(
      'success screen starts a new admission and returns to dashboard',
      (tester) async {
        useLargeSurface(tester);
        final services = servicesWith();
        await pushWizard(
          tester,
          studentService: services.studentService,
          familyService: services.familyService,
        );

        await selectFamily(tester, 'FAM-000001');
        await goToDetails(tester);
        await fillDetails(tester);
        await continueToReview(tester);
        await confirmAdmission(tester);

        // New Admission resets to a fresh wizard (step 1).
        await tester.tap(find.byKey(const Key('adm_success_new_admission')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('adm_family_search')), findsOneWidget);
        expect(services.studentRepo.all, hasLength(1));

        // Complete the second admission then return to the dashboard.
        await selectFamily(tester, 'FAM-000001');
        await goToDetails(tester);
        await fillDetails(tester, name: 'Sara Khan');
        await continueToReview(tester);
        await confirmAdmission(tester);
        expect(find.text('Admission saved'), findsOneWidget);

        await tester.tap(find.byKey(const Key('adm_success_dashboard')));
        await tester.pumpAndSettle();
        expect(find.text('open wizard'), findsOneWidget);
      },
    );
  });
}
