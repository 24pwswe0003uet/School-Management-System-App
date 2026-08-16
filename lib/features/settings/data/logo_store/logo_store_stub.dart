import 'dart:typed_data';

import 'package:school_office_management/features/settings/domain/repositories/settings_repository.dart';

/// Web fallback store. There is no filesystem on the web, so writes always
/// fail and the repository falls back to storing the logo as a SQLite BLOB.
LogoStore createLogoStore() => _UnsupportedLogoStore();

class _UnsupportedLogoStore implements LogoStore {
  @override
  Future<Uint8List?> read() async => null;

  @override
  Future<void> write({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    throw UnsupportedError(
      'File storage is unavailable on this platform.',
    );
  }

  @override
  Future<void> remove() async {}
}
