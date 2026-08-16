import 'dart:typed_data';

import '../entities/school_class.dart';
import '../entities/school_profile.dart';
import '../entities/school_section.dart';

/// Thrown when a data-entry user attempts to modify settings. Settings are
/// read-only for non-admin roles.
class SettingsPermissionException implements Exception {
  const SettingsPermissionException();

  @override
  String toString() => 'Only the school administrator can change settings.';
}

/// Thrown when a class or section name already exists (case-insensitive).
class DuplicateSettingsNameException implements Exception {
  const DuplicateSettingsNameException(this.kind, this.name);

  final String kind;
  final String name;

  @override
  String toString() => 'DuplicateSettingsNameException: $name already exists.';
}

/// Thrown when a settings value fails validation (missing name, bad phone,
/// bad email, malformed academic year, duplicate class/section).
class SettingsValidationException implements Exception {
  const SettingsValidationException(this.message);

  final String message;

  @override
  String toString() => 'SettingsValidationException: $message';
}

/// Persists the school profile, logo and canonical class/section lists.
abstract interface class SettingsRepository {
  // Profile --------------------------------------------------------------

  Future<SchoolProfile> getProfile();

  Future<SchoolProfile> saveProfile({
    required String schoolName,
    String address,
    String phone,
    String email,
    String academicYear,
    String receiptFooter,
  });

  /// Stores the logo via the backing [LogoStore] (file on IO platforms) or the
  /// SQLite BLOB fallback (web), then returns the updated profile.
  Future<SchoolProfile> updateLogo({
    required Uint8List bytes,
    required String mimeType,
  });

  /// Removes the stored logo and returns the updated profile.
  Future<SchoolProfile> removeLogo();

  Future<Uint8List?> getLogoBytes();

  // Classes ----------------------------------------------------------------

  Future<List<SchoolClass>> listClasses({bool includeInactive = false});

  Future<SchoolClass> addClass(String className);

  Future<SchoolClass> updateClass({
    required int id,
    required String className,
    bool renameStudents = false,
  });

  Future<void> setClassActive(int id, bool isActive);

  // Sections ----------------------------------------------------------------

  Future<List<SchoolSection>> listSections({bool includeInactive = false});

  Future<SchoolSection> addSection(String sectionName);

  Future<SchoolSection> updateSection({
    required int id,
    required String sectionName,
    bool renameStudents = false,
  });

  Future<void> setSectionActive(int id, bool isActive);
}

/// Reads and writes the school logo image. IO implementations persist to a
/// file in the application-support directory; the repository falls back to a
/// SQLite BLOB when writing to the file system is unavailable (web).
abstract interface class LogoStore {
  Future<Uint8List?> read();

  Future<void> write({required Uint8List bytes, required String mimeType});

  Future<void> remove();
}
