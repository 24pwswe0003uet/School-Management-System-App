import 'package:school_office_management/features/settings/domain/repositories/settings_repository.dart';

import 'logo_store_stub.dart'
    if (dart.library.io) 'logo_store_io.dart' as platform;

/// Creates the platform-appropriate [LogoStore]:
/// - IO platforms: a file store under the application-support directory.
/// - Web: a store whose writes fail, so the repository uses the SQLite BLOB
///   fallback.
LogoStore createLogoStore() => platform.createLogoStore();
