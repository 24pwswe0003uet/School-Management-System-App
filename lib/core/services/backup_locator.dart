export 'backup_locator_stub.dart'
    if (dart.library.io) 'backup_locator_io.dart';

/// Platform file/directory helpers for the backup module. Provides the stable
/// backup directory and can open it in the native file manager.
abstract class BackupLocator {
  /// The stable, app-scoped directory where backups are kept.
  Future<String> backupDirectory();

  /// Reveals [path] in the native file manager ("Show in folder").
  /// Returns false on platforms without a file manager.
  Future<bool> openDirectory(String path);
}
