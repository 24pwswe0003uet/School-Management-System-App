import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/family/domain/entities/family.dart';
import 'package:school_office_management/features/family/domain/services/family_service.dart';
import 'package:school_office_management/features/student/domain/entities/admission_history_entry.dart';
import 'package:school_office_management/features/student/domain/entities/student.dart';
import 'package:school_office_management/features/student/domain/entities/student_fee_history_item.dart';
import 'package:school_office_management/features/student/domain/entities/student_history_entry.dart';
import 'package:school_office_management/features/student/domain/services/student_service.dart';
import 'package:school_office_management/features/student/presentation/student_details_screen.dart';
import 'package:school_office_management/features/student/presentation/student_form_screen.dart';
import 'package:school_office_management/features/student/presentation/student_list_screen.dart';

import '../family/fakes/fake_family_repository.dart';
import 'fakes/fake_student_repository.dart';

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
  String? contactReference,
  String? notes,
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
    contactReference: contactReference,
    notes: notes,
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

/// Gives the details/form screens enough room that lazy ListViews build every
/// row (the test font is much wider than a real font).
void useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> pumpList(
  WidgetTester tester,
  StudentService studentService,
  FamilyService familyService,
) async {
  await tester.pumpWidget(
    wrap(
      StudentListScreen(
        studentService: studentService,
        familyService: familyService,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pushes the student form and returns a growable holder that receives the
/// popped result once the form is saved and popped.
Future<List<Student?>> pushAndOpen(
  WidgetTester tester, {
  required StudentService studentService,
  required FamilyService familyService,
  Student? existing,
}) async {
  final result = <Student?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result.add(
                  await Navigator.of(context).push<Student>(
                    MaterialPageRoute(
                      builder: (_) => StudentFormScreen(
                        studentService: studentService,
                        familyService: familyService,
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

/// Fills the student name (when given) and taps Save using fixed pumps —
/// `pumpAndSettle` cannot be used because the loading spinner animates while
/// the duplicate-warning dialog is open.
Future<void> submitStudentForm(
  WidgetTester tester, {
  String? name,
  Duration settle = const Duration(milliseconds: 350),
}) async {
  if (name != null) {
    await tester.enterText(find.byKey(const Key('student_name')), name);
  }
  final save = find.byKey(const Key('student_save'));
  await tester.ensureVisible(save);
  await tester.pump();
  await tester.tap(save);
  await tester.pump();
  await tester.pump(settle);
}

/// Selects a family in the create form's picker by tapping its result tile.
Future<void> pickFamily(WidgetTester tester, String familyId) async {
  final tile = find.byKey(ValueKey('family_pick_$familyId'));
  await tester.ensureVisible(tile);
  await tester.pump();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> pumpDetails(
  WidgetTester tester, {
  required StudentService studentService,
  required FamilyService familyService,
  required int studentId,
}) async {
  await tester.pumpWidget(
    wrap(
      StudentDetailsScreen(
        studentService: studentService,
        familyService: familyService,
        studentId: studentId,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('StudentListScreen', () {
    testWidgets('lists students with IDs, class, family and status', (
      tester,
    ) async {
      final services = servicesWith(
        students: [
          buildStudent(),
          buildStudent(
            id: 2,
            studentId: 'STU-000002',
            name: 'Usman Ali',
            className: 'Class 3',
            section: 'B',
            status: StudentStatus.left,
          ),
        ],
      );
      await pumpList(tester, services.studentService, services.familyService);

      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('Usman Ali'), findsOneWidget);
      expect(find.textContaining('STU-000001'), findsOneWidget);
      expect(find.textContaining('STU-000002'), findsOneWidget);
      expect(find.textContaining('Family: FAM-000001'), findsNWidgets(2));
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Left'), findsOneWidget);
    });

    testWidgets('shows an empty state when there are no students', (
      tester,
    ) async {
      final services = servicesWith(families: [buildFamily()]);
      await pumpList(tester, services.studentService, services.familyService);

      expect(find.text('No students found.'), findsOneWidget);
    });

    testWidgets('search filters by student name', (tester) async {
      final services = servicesWith(
        students: [
          buildStudent(),
          buildStudent(id: 2, studentId: 'STU-000002', name: 'Usman Ali'),
        ],
      );
      await pumpList(tester, services.studentService, services.familyService);

      await tester.enterText(
        find.byKey(const Key('student_search_field')),
        'usman',
      );
      await tester.pumpAndSettle();

      expect(find.text('Usman Ali'), findsOneWidget);
      expect(find.text('Ali Khan'), findsNothing);
    });

    testWidgets('search matches a guardian name', (tester) async {
      final services = servicesWith(students: [buildStudent()]);
      await pumpList(tester, services.studentService, services.familyService);

      await tester.enterText(
        find.byKey(const Key('student_search_field')),
        'ahmed',
      );
      await tester.pumpAndSettle();

      expect(find.text('Ali Khan'), findsOneWidget);
    });

    testWidgets('search matches a family phone without separators', (
      tester,
    ) async {
      final services = servicesWith(students: [buildStudent()]);
      await pumpList(tester, services.studentService, services.familyService);

      await tester.enterText(
        find.byKey(const Key('student_search_field')),
        '1234567',
      );
      await tester.pumpAndSettle();

      expect(find.text('Ali Khan'), findsOneWidget);
    });

    testWidgets('status filter narrows the list', (tester) async {
      final services = servicesWith(
        students: [
          buildStudent(),
          buildStudent(
            id: 2,
            studentId: 'STU-000002',
            name: 'Usman Ali',
            status: StudentStatus.left,
          ),
        ],
      );
      await pumpList(tester, services.studentService, services.familyService);

      await tester.tap(find.byKey(const Key('student_status_filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Left').last);
      await tester.pumpAndSettle();

      expect(find.text('Usman Ali'), findsOneWidget);
      expect(find.text('Ali Khan'), findsNothing);
    });

    testWidgets('class filter narrows the list', (tester) async {
      final services = servicesWith(
        students: [
          buildStudent(),
          buildStudent(
            id: 2,
            studentId: 'STU-000002',
            name: 'Usman Ali',
            className: 'Class 3',
          ),
        ],
      );
      await pumpList(tester, services.studentService, services.familyService);

      await tester.tap(find.byKey(const Key('student_class_filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Class 3').last);
      await tester.pumpAndSettle();

      expect(find.text('Usman Ali'), findsOneWidget);
      expect(find.text('Ali Khan'), findsNothing);
    });

    testWidgets('shows an error state and recovers via retry', (tester) async {
      final services = servicesWith(students: [buildStudent()]);
      services.studentRepo.failSearch = true;
      await pumpList(tester, services.studentService, services.familyService);

      expect(find.text('Students could not be loaded.'), findsOneWidget);

      services.studentRepo.failSearch = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Ali Khan'), findsOneWidget);
    });

    testWidgets('opens the create form via the FAB', (tester) async {
      useLargeSurface(tester);
      final services = servicesWith();
      await pumpList(tester, services.studentService, services.familyService);

      await tester.tap(find.byKey(const Key('student_add_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Add Student'), findsWidgets);
      expect(find.text('STU-000001'), findsOneWidget);
      expect(
        find.byKey(const Key('student_family_picker_search')),
        findsOneWidget,
      );
    });

    testWidgets('tapping a student card opens its details', (tester) async {
      final services = servicesWith(students: [buildStudent()]);
      await pumpList(tester, services.studentService, services.familyService);

      await tester.tap(find.text('Ali Khan'));
      await tester.pumpAndSettle();

      expect(find.text('Student Details'), findsOneWidget);
      expect(find.text('STU-000001'), findsOneWidget);
    });
  });

  group('StudentFormScreen', () {
    testWidgets('validates the name and requires a family', (tester) async {
      useLargeSurface(tester);
      final services = servicesWith();
      await pushAndOpen(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
      );

      await submitStudentForm(tester);

      expect(find.text('Please enter the student full name.'), findsOneWidget);
      expect(
        find.text('A family must be selected for the student.'),
        findsNothing,
      );

      await tester.enterText(find.byKey(const Key('student_name')), 'Ali Khan');
      await submitStudentForm(tester);

      expect(
        find.text('A family must be selected for the student.'),
        findsOneWidget,
      );
    });

    testWidgets('creates a student after picking a family', (tester) async {
      useLargeSurface(tester);
      final services = servicesWith();
      final result = await pushAndOpen(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
      );

      await pickFamily(tester, 'FAM-000001');
      expect(find.byKey(const Key('student_change_family')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('student_name')), 'Ali Khan');
      await tester.enterText(find.byKey(const Key('student_class')), 'Class 5');
      await submitStudentForm(tester);

      expect(result.single?.name, 'Ali Khan');
      expect(result.single?.studentId, 'STU-000001');
      expect(result.single?.familyId, 1);
      expect(result.single?.className, 'Class 5');
    });

    testWidgets('offers to create a family and auto-selects it', (
      tester,
    ) async {
      useLargeSurface(tester);
      final services = servicesWith(families: []);
      final result = await pushAndOpen(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
      );

      expect(find.text('No family exists yet.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('student_create_family')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('family_guardian')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('family_guardian')),
        'Ahmed Khan',
      );
      final familySave = find.byKey(const Key('family_save'));
      await tester.ensureVisible(familySave);
      await tester.pump();
      await tester.tap(familySave);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('student_change_family')), findsOneWidget);
      expect(find.text('FAM-000001'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('student_name')), 'Ali Khan');
      await submitStudentForm(tester);

      expect(result.single?.name, 'Ali Khan');
      expect(result.single?.studentId, 'STU-000001');
      expect(result.single?.familyId, 1000);
    });

    testWidgets('duplicate warning Cancel aborts the save', (tester) async {
      useLargeSurface(tester);
      final services = servicesWith(students: [buildStudent()]);
      await pushAndOpen(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
      );

      await pickFamily(tester, 'FAM-000001');
      await submitStudentForm(tester, name: 'Ali Khan');

      expect(find.text('Possible existing students'), findsOneWidget);
      expect(find.byKey(const Key('stu_dup_STU-000001')), findsOneWidget);

      await tester.tap(find.byKey(const Key('stu_dup_cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Possible existing students'), findsNothing);
      expect(services.studentRepo.all, hasLength(1));
      expect(find.text('Add Student'), findsWidgets);
    });

    testWidgets('Save anyway creates a second student', (tester) async {
      useLargeSurface(tester);
      final services = servicesWith(students: [buildStudent()]);
      final result = await pushAndOpen(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
      );

      await pickFamily(tester, 'FAM-000001');
      await submitStudentForm(tester, name: 'Ali Khan');

      await tester.tap(find.byKey(const Key('stu_dup_save_anyway')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(result.single?.studentId, 'STU-000002');
      expect(services.studentRepo.all, hasLength(2));
    });

    testWidgets('View opens the matched student profile', (tester) async {
      useLargeSurface(tester);
      final services = servicesWith(students: [buildStudent()]);
      await pushAndOpen(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
      );

      await pickFamily(tester, 'FAM-000001');
      await submitStudentForm(tester, name: 'Ali Khan');

      await tester.tap(find.byKey(const Key('stu_dup_STU-000001')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Student Details'), findsOneWidget);
      expect(find.text('Ali Khan'), findsWidgets);
    });

    testWidgets('edit mode prefills values and saves changes', (tester) async {
      useLargeSurface(tester);
      final services = servicesWith(students: [buildStudent()]);
      final result = await pushAndOpen(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
        existing: buildStudent(),
      );

      expect(find.text('Edit Student'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('FAM-000001'), findsOneWidget);

      await submitStudentForm(tester, name: 'Zain Khan');

      expect(result.single?.name, 'Zain Khan');
      expect(result.single?.studentId, 'STU-000001');
    });
  });

  group('StudentDetailsScreen', () {
    testWidgets('shows personal, family, academic, fee and history cards', (
      tester,
    ) async {
      useLargeSurface(tester);
      final services = servicesWith(students: [buildStudent()]);
      services.studentRepo.seedAdmissions(1, [
        AdmissionHistoryEntry(
          id: 1,
          admissionId: 'ADM-000001',
          admissionDate: DateTime(2026, 8, 1),
          className: 'Class 5',
          section: 'A',
        ),
      ]);
      services.studentRepo.seedHistory(1, [
        StudentHistoryEntry(
          id: 1,
          className: 'Class 4',
          section: 'B',
          status: 'active',
          changedAt: DateTime(2026, 7, 1),
        ),
      ]);
      services.studentRepo.seedFeeHistory(1, [
        StudentFeeHistoryItem(
          feeRecordId: 1,
          feeRecordCode: 'FEE-000001',
          periodStart: DateTime(2026, 8, 1),
          periodEnd: DateTime(2026, 8, 31),
          expected: 5000,
          paid: 2000,
          status: 'partial',
        ),
      ]);
      services.studentRepo.seedOutstanding(1, 3000);
      await pumpDetails(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
        studentId: 1,
      );

      expect(find.text('Student Details'), findsOneWidget);
      expect(find.text('Ali Khan'), findsWidgets);
      expect(find.text('STU-000001'), findsOneWidget);

      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('1 Aug 2020'), findsOneWidget);

      expect(find.text('Family Information'), findsOneWidget);
      expect(find.text('Ahmed Khan'), findsWidgets);
      expect(find.text('Sara Khan'), findsOneWidget);
      expect(find.text('0300-1234567'), findsOneWidget);

      expect(find.text('Academic Information'), findsOneWidget);
      expect(find.text('Class 5'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);

      expect(find.text('Fee Summary'), findsOneWidget);
      expect(find.text('Rs 3,000'), findsWidgets);
      expect(find.text('Aug 2026'), findsOneWidget);
      expect(
        find.text('Expected Rs 5,000 · Paid Rs 2,000 · Due Rs 3,000'),
        findsOneWidget,
      );
      expect(find.text('Partial'), findsOneWidget);

      expect(find.text('Admission History'), findsOneWidget);
      expect(find.text('ADM-000001'), findsOneWidget);

      expect(find.text('Academic History'), findsOneWidget);
      expect(find.text('Class 4 · B'), findsOneWidget);
      expect(find.text('1 Jul 2026'), findsOneWidget);

      expect(find.byKey(const Key('student_edit')), findsOneWidget);
      expect(find.byKey(const Key('student_change_status')), findsOneWidget);
    });

    testWidgets('shows empty fee/admission/history placeholders', (
      tester,
    ) async {
      useLargeSurface(tester);
      final services = servicesWith(students: [buildStudent()]);
      await pumpDetails(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
        studentId: 1,
      );

      expect(
        find.text('Fee records will appear here when the Fee module is added.'),
        findsOneWidget,
      );
      expect(find.text('No admission history.'), findsOneWidget);
      expect(
        find.text('No class or status changes recorded yet.'),
        findsOneWidget,
      );
    });

    testWidgets('change status updates the profile and history', (
      tester,
    ) async {
      useLargeSurface(tester);
      final services = servicesWith(students: [buildStudent()]);
      await pumpDetails(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
        studentId: 1,
      );

      await tester.tap(find.byKey(const Key('student_change_status')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Change status'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('student_status_left')));
      await tester.pumpAndSettle();

      expect(find.text('Left'), findsWidgets);
      expect(find.text('Active'), findsNothing);
      expect(services.studentRepo.all.single.status, StudentStatus.left);
    });

    testWidgets('opens the linked family profile', (tester) async {
      useLargeSurface(tester);
      final services = servicesWith(students: [buildStudent()]);
      await pumpDetails(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
        studentId: 1,
      );

      await tester.tap(find.byKey(const Key('student_open_family')));
      await tester.pumpAndSettle();

      expect(find.text('Family Details'), findsOneWidget);
      expect(find.text('Ahmed Khan'), findsWidgets);
    });

    testWidgets('edit opens the prefilled form and details refresh', (
      tester,
    ) async {
      useLargeSurface(tester);
      final services = servicesWith(students: [buildStudent()]);
      await pumpDetails(
        tester,
        studentService: services.studentService,
        familyService: services.familyService,
        studentId: 1,
      );

      await tester.tap(find.byKey(const Key('student_edit')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Student'), findsOneWidget);
      expect(find.text('Ali Khan'), findsOneWidget);

      await submitStudentForm(tester, name: 'Zain Khan');
      await tester.pumpAndSettle();

      expect(find.text('Student Details'), findsOneWidget);
      expect(find.text('Zain Khan'), findsWidgets);
      expect(find.text('Ali Khan'), findsNothing);
    });
  });
}
