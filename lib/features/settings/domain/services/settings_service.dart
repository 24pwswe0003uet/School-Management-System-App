import 'package:flutter/foundation.dart';

import '../../../auth/domain/entities/app_role.dart';
import '../../../auth/domain/services/auth_service.dart';
import '../entities/school_class.dart';
import '../entities/school_profile.dart';
import '../entities/school_section.dart';
import '../repositories/settings_repository.dart';

/// Holds the school profile, logo state and canonical class/section lists and
/// exposes settings operations to the screens.
///
/// Only the school admin may modify settings — every mutating method calls
/// [_requireAdmin] and throws [SettingsPermissionException] for other roles.
class SettingsService extends ChangeNotifier {
  SettingsService({
    required SettingsRepository repository,
    required AuthService authService,
  })  : _repository = repository,
        _authService = authService;

  final SettingsRepository _repository;
  final AuthService _authService;

  SchoolProfile _profile = const SchoolProfile();
  List<SchoolClass> _classes = const [];
  List<SchoolSection> _sections = const [];
  bool _loaded = false;
  bool _loading = false;
  Object? _error;

  SchoolProfile get profile => _profile;
  bool get isLoaded => _loaded;
  bool get isLoading => _loading;
  Object? get error => _error;
  bool get isAdmin => _authService.currentUser?.role == AppRole.schoolAdmin;

  /// All classes, including inactive ones (for management screens).
  List<SchoolClass> get allClasses => _classes;

  /// Active classes only (for student forms and fee generation).
  List<SchoolClass> get activeClasses =>
      _classes.where((c) => c.isActive).toList();

  /// All sections, including inactive ones (for management screens).
  List<SchoolSection> get allSections => _sections;

  /// Active sections only (for student forms).
  List<SchoolSection> get activeSections =>
      _sections.where((s) => s.isActive).toList();

  /// Loads profile, classes and sections. Safe to call repeatedly; reloads
  /// whenever the screens or other modules need fresh data.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _repository.getProfile();
      _classes = await _repository.listClasses(includeInactive: true);
      _sections = await _repository.listSections(includeInactive: true);
      _loaded = true;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Profile ------------------------------------------------------------------

  Future<void> saveProfile({
    required String schoolName,
    String address = '',
    String phone = '',
    String email = '',
    String academicYear = '',
    String receiptFooter = '',
  }) async {
    _requireAdmin();
    final nameError = validateSchoolName(schoolName);
    if (nameError != null) {
      throw SettingsValidationException(nameError);
    }
    final phoneError = validatePhone(phone);
    if (phoneError != null) {
      throw SettingsValidationException(phoneError);
    }
    final emailError = validateEmail(email);
    if (emailError != null) {
      throw SettingsValidationException(emailError);
    }
    final yearError = validateAcademicYear(academicYear);
    if (yearError != null) {
      throw SettingsValidationException(yearError);
    }
    _profile = await _repository.saveProfile(
      schoolName: schoolName.trim(),
      address: address.trim(),
      phone: phone.trim(),
      email: email.trim(),
      academicYear: academicYear.trim(),
      receiptFooter: receiptFooter.trim(),
    );
    notifyListeners();
  }

  Future<void> updateLogo({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    _requireAdmin();
    if (!isSupportedLogoMime(mimeType)) {
      throw const SettingsValidationException(
        'Only PNG or JPEG images can be used as the logo.',
      );
    }
    if (bytes.length > 1024 * 1024) {
      throw const SettingsValidationException(
        'The logo must be 1 MB or smaller.',
      );
    }
    _profile = await _repository.updateLogo(bytes: bytes, mimeType: mimeType);
    notifyListeners();
  }

  Future<void> removeLogo() async {
    _requireAdmin();
    _profile = await _repository.removeLogo();
    notifyListeners();
  }

  /// The raw logo bytes for previews, receipts and report exports.
  Future<Uint8List?> getLogoBytes() => _repository.getLogoBytes();

  // Classes ------------------------------------------------------------------

  Future<SchoolClass> addClass(String className) async {
    _requireAdmin();
    final name = className.trim();
    if (name.isEmpty) {
      throw const SettingsValidationException('Class name is required.');
    }
    _ensureUniqueClass(name);
    final created = await _repository.addClass(name);
    await _reloadClasses();
    return created;
  }

  Future<SchoolClass> updateClass({
    required int id,
    required String className,
    bool renameStudents = false,
  }) async {
    _requireAdmin();
    final name = className.trim();
    if (name.isEmpty) {
      throw const SettingsValidationException('Class name is required.');
    }
    final current = _classes.firstWhere(
      (c) => c.id == id,
      orElse: () => SchoolClass(
        id: id,
        className: name,
        isActive: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    if (current.className.toLowerCase() != name.toLowerCase()) {
      _ensureUniqueClass(name);
    }
    final updated = await _repository.updateClass(
      id: id,
      className: name,
      renameStudents: renameStudents,
    );
    await _reloadClasses();
    return updated;
  }

  Future<void> setClassActive(int id, bool isActive) async {
    _requireAdmin();
    await _repository.setClassActive(id, isActive);
    await _reloadClasses();
  }

  // Sections ------------------------------------------------------------------

  Future<SchoolSection> addSection(String sectionName) async {
    _requireAdmin();
    final name = sectionName.trim();
    if (name.isEmpty) {
      throw const SettingsValidationException('Section name is required.');
    }
    _ensureUniqueSection(name);
    final created = await _repository.addSection(name);
    await _reloadSections();
    return created;
  }

  Future<SchoolSection> updateSection({
    required int id,
    required String sectionName,
    bool renameStudents = false,
  }) async {
    _requireAdmin();
    final name = sectionName.trim();
    if (name.isEmpty) {
      throw const SettingsValidationException('Section name is required.');
    }
    final current = _sections.firstWhere(
      (s) => s.id == id,
      orElse: () => SchoolSection(
        id: id,
        sectionName: name,
        isActive: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    if (current.sectionName.toLowerCase() != name.toLowerCase()) {
      _ensureUniqueSection(name);
    }
    final updated = await _repository.updateSection(
      id: id,
      sectionName: name,
      renameStudents: renameStudents,
    );
    await _reloadSections();
    return updated;
  }

  Future<void> setSectionActive(int id, bool isActive) async {
    _requireAdmin();
    await _repository.setSectionActive(id, isActive);
    await _reloadSections();
  }

  // Validation ----------------------------------------------------------------

  static String? validateSchoolName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'School name is required.';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final clean = value.replaceAll(RegExp(r'[\s\-().]'), '').replaceAll(
      RegExp(r'^\+'),
      '',
    );
    if (!RegExp(r'^\d{7,15}$').hasMatch(clean)) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? validateAcademicYear(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!RegExp(r'^\d{4}\s*[-–]\s*\d{4}$').hasMatch(value.trim())) {
      return 'Use the format 2025–2026.';
    }
    return null;
  }

  static String? validateEntityName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required.';
    }
    return null;
  }

  static bool isSupportedLogoMime(String mimeType) =>
      mimeType == 'image/png' || mimeType == 'image/jpeg';

  // Internals ---------------------------------------------------------------

  void _requireAdmin() {
    if (!isAdmin) {
      throw const SettingsPermissionException();
    }
  }

  void _ensureUniqueClass(String name) {
    if (_classes.any((c) => c.className.toLowerCase() == name.toLowerCase())) {
      throw SettingsValidationException('Class "$name" already exists.');
    }
  }

  void _ensureUniqueSection(String name) {
    if (_sections.any((s) => s.sectionName.toLowerCase() == name.toLowerCase())) {
      throw SettingsValidationException('Section "$name" already exists.');
    }
  }

  Future<void> _reloadClasses() async {
    _classes = await _repository.listClasses(includeInactive: true);
    notifyListeners();
  }

  Future<void> _reloadSections() async {
    _sections = await _repository.listSections(includeInactive: true);
    notifyListeners();
  }
}
