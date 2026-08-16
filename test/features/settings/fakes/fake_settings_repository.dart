import 'dart:typed_data';

import 'package:school_office_management/features/settings/domain/entities/school_class.dart';
import 'package:school_office_management/features/settings/domain/entities/school_profile.dart';
import 'package:school_office_management/features/settings/domain/entities/school_section.dart';
import 'package:school_office_management/features/settings/domain/repositories/settings_repository.dart';

/// In-memory [SettingsRepository] + [LogoStore] for widget tests.
///
/// Comes pre-seeded with the migration-V12 defaults (classes Play Group
/// through 12, sections A/B/C) so student/admission dropdowns work without
/// extra setup.
class FakeSettingsRepository implements SettingsRepository, LogoStore {
  FakeSettingsRepository({
    this.profile = const SchoolProfile(),
    List<SchoolClass>? classes,
    List<SchoolSection>? sections,
  })  :         _classes = classes ??
            [
              for (final name in [
                'Play Group',
                'Nursery',
                'KG',
                '3',
                '4',
                '5',
                '6',
                '7',
                '9',
                '1',
                '2',
                '3',
                '4',
                '5',
                '6',
                '7',
                '8',
                '9',
                '10',
                '11',
                '12',
              ])
                _class(name),
            ],
        _sections = sections ??
            [for (final name in ['A', 'B', 'C']) _section(name)];

  static SchoolClass _class(String name, {bool isActive = true}) {
    final now = DateTime.utc(2026, 1, 1);
    return SchoolClass(
      id: name.hashCode & 0x7fffffff,
      className: name,
      isActive: isActive,
      createdAt: now,
      updatedAt: now,
    );
  }

  static SchoolSection _section(String name, {bool isActive = true}) {
    final now = DateTime.utc(2026, 1, 1);
    return SchoolSection(
      id: name.hashCode & 0x7fffffff,
      sectionName: name,
      isActive: isActive,
      createdAt: now,
      updatedAt: now,
    );
  }

  SchoolProfile profile;
  List<SchoolClass> _classes;
  List<SchoolSection> _sections;
  Uint8List? _logoBytes;

  // Profile ------------------------------------------------------------------

  @override
  Future<SchoolProfile> getProfile() async => profile;

  @override
  Future<SchoolProfile> saveProfile({
    required String schoolName,
    String address = '',
    String phone = '',
    String email = '',
    String academicYear = '',
    String receiptFooter = '',
  }) async {
    profile = profile.copyWith(
      schoolName: schoolName,
      address: address,
      phone: phone,
      email: email,
      academicYear: academicYear,
      receiptFooter: receiptFooter,
    );
    return profile;
  }

  @override
  Future<SchoolProfile> updateLogo({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    _logoBytes = bytes;
    profile = profile.copyWith(
      logoKind: LogoKind.file,
      logoMimeType: mimeType,
    );
    return profile;
  }

  @override
  Future<SchoolProfile> removeLogo() async {
    _logoBytes = null;
    profile = profile.copyWith(
      logoKind: LogoKind.none,
      logoFileName: null,
      logoMimeType: null,
    );
    return profile;
  }

  @override
  Future<Uint8List?> getLogoBytes() async => _logoBytes;

  // Classes ------------------------------------------------------------------

  @override
  Future<List<SchoolClass>> listClasses({bool includeInactive = false}) async {
    return _classes
        .where((c) => includeInactive || c.isActive)
        .toList()
      ..sort((a, b) => a.className.compareTo(b.className));
  }

  @override
  Future<SchoolClass> addClass(String className) async {
    _ensureUnique(_classes.map((c) => c.className), 'Class', className);
    final created = _class(className.trim());
    _classes = [..._classes, created];
    return created;
  }

  @override
  Future<SchoolClass> updateClass({
    required int id,
    required String className,
    bool renameStudents = false,
  }) async {
    final existing = _classes.firstWhere((c) => c.id == id);
    final name = className.trim();
    _ensureUnique(
      _classes.where((c) => c.id != id).map((c) => c.className),
      'Class',
      name,
    );
    final updated = existing.copyWith(
      className: name,
      updatedAt: DateTime.now(),
    );
    _classes = [
      for (final c in _classes) c.id == id ? updated : c,
    ];
    return updated;
  }

  @override
  Future<void> setClassActive(int id, bool isActive) async {
    _classes = [
      for (final c in _classes)
        c.id == id ? c.copyWith(isActive: isActive) : c,
    ];
  }

  // Sections -----------------------------------------------------------------

  @override
  Future<List<SchoolSection>> listSections({bool includeInactive = false}) async {
    return _sections
        .where((s) => includeInactive || s.isActive)
        .toList()
      ..sort((a, b) => a.sectionName.compareTo(b.sectionName));
  }

  @override
  Future<SchoolSection> addSection(String sectionName) async {
    _ensureUnique(
      _sections.map((s) => s.sectionName),
      'Section',
      sectionName,
    );
    final created = _section(sectionName.trim());
    _sections = [..._sections, created];
    return created;
  }

  @override
  Future<SchoolSection> updateSection({
    required int id,
    required String sectionName,
    bool renameStudents = false,
  }) async {
    final existing = _sections.firstWhere((s) => s.id == id);
    final name = sectionName.trim();
    _ensureUnique(
      _sections.where((s) => s.id != id).map((s) => s.sectionName),
      'Section',
      name,
    );
    final updated = SchoolSection(
      id: existing.id,
      sectionName: name,
      isActive: existing.isActive,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      activeStudentCount: existing.activeStudentCount,
    );
    _sections = [
      for (final s in _sections) s.id == id ? updated : s,
    ];
    return updated;
  }

  @override
  Future<void> setSectionActive(int id, bool isActive) async {
    _sections = [
      for (final s in _sections)
        s.id == id
            ? SchoolSection(
                id: s.id,
                sectionName: s.sectionName,
                isActive: isActive,
                createdAt: s.createdAt,
                updatedAt: s.updatedAt,
                activeStudentCount: s.activeStudentCount,
              )
            : s,
    ];
  }

  // LogoStore ----------------------------------------------------------------

  @override
  Future<Uint8List?> read() async => _logoBytes;

  @override
  Future<void> write({required Uint8List bytes, required String mimeType}) async {
    _logoBytes = bytes;
  }

  @override
  Future<void> remove() async {
    _logoBytes = null;
  }

  void _ensureUnique(Iterable<String> names, String kind, String name) {
    final trimmed = name.trim();
    if (names.any((n) => n.toLowerCase() == trimmed.toLowerCase())) {
      throw DuplicateSettingsNameException(kind, trimmed);
    }
  }
}
