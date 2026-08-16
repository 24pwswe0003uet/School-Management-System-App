import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/auth/domain/services/auth_service.dart';
import 'package:school_office_management/features/settings/domain/entities/school_class.dart';
import 'package:school_office_management/features/settings/domain/entities/school_profile.dart';
import 'package:school_office_management/features/settings/domain/entities/school_section.dart';
import 'package:school_office_management/features/settings/domain/repositories/settings_repository.dart';
import 'package:school_office_management/features/settings/domain/services/settings_service.dart';

import 'fakes/fake_settings_repository.dart';
import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSettingsRepository repository;
  late AuthService authService;
  late SettingsService service;

  Future<void> build({bool admin = true}) async {
    repository = FakeSettingsRepository();
    authService =
        admin ? await buildTestAdminAuthService() : await buildTestDataEntryAuthService();
    service = SettingsService(repository: repository, authService: authService);
    await service.load();
  }

  group('load', () {
    test('populates profile, classes and sections', () async {
      await build();
      expect(service.isLoaded, isTrue);
      expect(service.profile.schoolName, '');
      expect(service.allClasses, isNotEmpty);
      expect(service.activeClasses.length, service.allClasses.length);
      expect(service.allSections.map((s) => s.sectionName), containsAll(['A', 'B', 'C']));
      expect(service.activeSections, hasLength(3));
    });

    test('records repository errors instead of throwing', () async {
      final repo = _ThrowingRepository();
      service = SettingsService(
        repository: repo,
        authService: await buildTestAdminAuthService(),
      );
      await service.load();
      expect(service.isLoaded, isFalse);
      expect(service.error, isA<UnsupportedError>());
    });
  });

  group('admin gate', () {
    test('data entry users cannot save the profile', () async {
      await build(admin: false);
      await expectLater(
        service.saveProfile(schoolName: 'Nope'),
        throwsA(isA<SettingsPermissionException>()),
      );
    });

    test('data entry users cannot change classes or sections', () async {
      await build(admin: false);
      await expectLater(
        service.addClass('9'),
        throwsA(isA<SettingsPermissionException>()),
      );
      await expectLater(
        service.addSection('D'),
        throwsA(isA<SettingsPermissionException>()),
      );
      await expectLater(
        service.setClassActive(1, false),
        throwsA(isA<SettingsPermissionException>()),
      );
    });

    test('data entry users cannot change the logo', () async {
      await build(admin: false);
      await expectLater(
        service.updateLogo(bytes: Uint8List.fromList([1]), mimeType: 'image/png'),
        throwsA(isA<SettingsPermissionException>()),
      );
      await expectLater(
        service.removeLogo(),
        throwsA(isA<SettingsPermissionException>()),
      );
    });

    test('admins can save the profile', () async {
      await build();
      await service.saveProfile(
        schoolName: '  Bright Future School  ',
        phone: '+92 300-1234567',
      );
      expect(service.profile.schoolName, 'Bright Future School');
      expect(service.profile.phone, '+92 300-1234567');
    });
  });

  group('profile validation', () {
    test('empty school name is rejected', () async {
      await build();
      await expectLater(
        service.saveProfile(schoolName: '   '),
        throwsA(
          isA<SettingsValidationException>()
              .having((e) => e.message, 'message', 'School name is required.'),
        ),
      );
    });

    test('invalid phone is rejected', () async {
      await build();
      await expectLater(
        service.saveProfile(schoolName: 'School', phone: 'abc'),
        throwsA(isA<SettingsValidationException>()),
      );
    });

    test('invalid email is rejected', () async {
      await build();
      await expectLater(
        service.saveProfile(schoolName: 'School', email: 'not-an-email'),
        throwsA(isA<SettingsValidationException>()),
      );
    });

    test('malformed academic year is rejected', () async {
      await build();
      await expectLater(
        service.saveProfile(schoolName: 'School', academicYear: '2025'),
        throwsA(
          isA<SettingsValidationException>()
              .having((e) => e.message, 'message', 'Use the format 2025–2026.'),
        ),
      );
    });
  });

  group('classes', () {
    test('addClass trims, persists and refreshes the list', () async {
      await build();
      final created = await service.addClass('  Six  ');
      expect(created.className, 'Six');
      expect(
        service.allClasses.any((c) => c.className == 'Six'),
        isTrue,
      );
    });

    test('empty and duplicate class names are rejected', () async {
      await build();
      await expectLater(
        service.addClass('  '),
        throwsA(
          isA<SettingsValidationException>()
              .having((e) => e.message, 'message', 'Class name is required.'),
        ),
      );
      await expectLater(
        service.addClass('5'),
        throwsA(
          isA<SettingsValidationException>()
              .having((e) => e.message, 'message', 'Class "5" already exists.'),
        ),
      );
      await expectLater(
        service.addClass('PLAY GROUP'),
        throwsA(isA<SettingsValidationException>()),
      );
    });

    test('setClassActive moves a class out of activeClasses', () async {
      await build();
      final class5 = service.allClasses.firstWhere((c) => c.className == '5');
      await service.setClassActive(class5.id, false);
      expect(
        service.activeClasses.any((c) => c.className == '5'),
        isFalse,
      );
      expect(
        service.allClasses.firstWhere((c) => c.id == class5.id).isActive,
        isFalse,
      );
    });

    test('updateClass trims and refreshes the list', () async {
      await build();
      final class5 = service.allClasses.firstWhere((c) => c.className == '5');
      await service.updateClass(id: class5.id, className: '  Five  ');
      expect(
        service.allClasses.any((c) => c.className == 'Five'),
        isTrue,
      );
      expect(
        service.allClasses.any((c) => c.className == '5'),
        isFalse,
      );
    });

    test('renaming onto an existing name is rejected', () async {
      await build();
      final class5 = service.allClasses.firstWhere((c) => c.className == '5');
      await expectLater(
        service.updateClass(id: class5.id, className: '6'),
        throwsA(isA<SettingsValidationException>()),
      );
    });
  });

  group('sections', () {
    test('addSection trims and duplicate is rejected case-insensitively', () async {
      await build();
      final created = await service.addSection('  D  ');
      expect(created.sectionName, 'D');
      await expectLater(
        service.addSection('a'),
        throwsA(isA<SettingsValidationException>()),
      );
    });

    test('setSectionActive filters activeSections', () async {
      await build();
      final sectionA = service.allSections.firstWhere((s) => s.sectionName == 'A');
      await service.setSectionActive(sectionA.id, false);
      expect(
        service.activeSections.any((s) => s.sectionName == 'A'),
        isFalse,
      );
    });

    test('updateSection persists the new name', () async {
      await build();
      final sectionA = service.allSections.firstWhere((s) => s.sectionName == 'A');
      await service.updateSection(id: sectionA.id, sectionName: 'Alpha');
      expect(
        service.allSections.any((s) => s.sectionName == 'Alpha'),
        isTrue,
      );
    });
  });

  group('logo', () {
    test('unsupported mime type and oversized logos are rejected', () async {
      await build();
      await expectLater(
        service.updateLogo(
          bytes: Uint8List.fromList([1]),
          mimeType: 'image/gif',
        ),
        throwsA(isA<SettingsValidationException>()),
      );
      await expectLater(
        service.updateLogo(
          bytes: Uint8List(1024 * 1024 + 1),
          mimeType: 'image/png',
        ),
        throwsA(isA<SettingsValidationException>()),
      );
    });

    test('updateLogo stores bytes and removeLogo clears them', () async {
      await build();
      final bytes = Uint8List.fromList([1, 2, 3]);
      await service.updateLogo(bytes: bytes, mimeType: 'image/png');
      expect(service.profile.hasLogo, isTrue);
      expect(await service.getLogoBytes(), bytes);

      await service.removeLogo();
      expect(service.profile.hasLogo, isFalse);
      expect(await service.getLogoBytes(), isNull);
    });
  });
}

class _ThrowingRepository implements SettingsRepository {
  @override
  Future<SchoolProfile> getProfile() async {
    throw UnsupportedError('no repo');
  }

  @override
  Future<SchoolProfile> saveProfile({
    required String schoolName,
    String address = '',
    String phone = '',
    String email = '',
    String academicYear = '',
    String receiptFooter = '',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SchoolProfile> updateLogo({
    required Uint8List bytes,
    required String mimeType,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SchoolProfile> removeLogo() => throw UnimplementedError();

  @override
  Future<Uint8List?> getLogoBytes() => throw UnimplementedError();

  @override
  Future<List<SchoolClass>> listClasses({bool includeInactive = false}) {
    throw UnimplementedError();
  }

  @override
  Future<SchoolClass> addClass(String className) {
    throw UnimplementedError();
  }

  @override
  Future<SchoolClass> updateClass({
    required int id,
    required String className,
    bool renameStudents = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> setClassActive(int id, bool isActive) => throw UnimplementedError();

  @override
  Future<List<SchoolSection>> listSections({bool includeInactive = false}) {
    throw UnimplementedError();
  }

  @override
  Future<SchoolSection> addSection(String sectionName) {
    throw UnimplementedError();
  }

  @override
  Future<SchoolSection> updateSection({
    required int id,
    required String sectionName,
    bool renameStudents = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> setSectionActive(int id, bool isActive) {
    throw UnimplementedError();
  }
}
