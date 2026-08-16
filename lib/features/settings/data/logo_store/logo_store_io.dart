import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:school_office_management/features/settings/domain/repositories/settings_repository.dart';

/// Creates the platform store. Exposed through [createLogoStore] via a
/// conditional import so `dart:io` never ships to the web build.
LogoStore createLogoStore() => FileLogoStore();

/// Persists the school logo as a file under the application-support
/// directory, e.g. `...\logos\school_logo.png`.
class FileLogoStore implements LogoStore {
  FileLogoStore({Directory? directory}) : _directoryOverride = directory;

  /// Test seam — when set, all reads/writes stay inside this directory.
  final Directory? _directoryOverride;

  Future<Directory> _logoDirectory() async {
    final base = _directoryOverride ??
        await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'logos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _extFor(String mimeType) => switch (mimeType) {
        'image/png' => 'png',
        'image/jpeg' => 'jpg',
        _ => 'bin',
      };

  @override
  Future<void> write({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final dir = await _logoDirectory();
    await _removeExistingLogo(dir);
    final file = File(p.join(dir.path, 'school_logo.${_extFor(mimeType)}'));
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List?> read() async {
    final dir = await _logoDirectory();
    final file = await _existingLogo(dir);
    if (file == null) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> remove() async {
    final dir = await _logoDirectory();
    await _removeExistingLogo(dir);
  }

  Future<void> _removeExistingLogo(Directory dir) async {
    final file = await _existingLogo(dir);
    if (file != null && await file.exists()) {
      await file.delete();
    }
  }

  /// The current logo file, matching `school_logo.<any extension>`.
  Future<File?> _existingLogo(Directory dir) async {
    if (!await dir.exists()) return null;
    await for (final entity in dir.list()) {
      if (entity is File &&
          p.basename(entity.path).startsWith('school_logo.')) {
        return entity;
      }
    }
    return null;
  }
}
