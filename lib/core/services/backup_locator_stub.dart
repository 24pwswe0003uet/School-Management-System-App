import 'backup_locator.dart';

/// Web has no filesystem; backups are not supported in this build. The
/// concrete factories in the io/stub pair are selected by a conditional import.
BackupLocator createBackupLocator() => throw UnsupportedError(
      'Backups require a local filesystem, which is not available on the web.',
    );
