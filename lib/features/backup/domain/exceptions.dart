/// Base class for backup/restore failures surfaced to the user as a plain
/// message (never a raw stack trace).
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => 'BackupException: $message';
}

/// The selected backup file could not be read or is not a valid SQLite
/// database. Restore is refused.
class BackupInvalidException extends BackupException {
  const BackupInvalidException(String file)
      : super('The selected file is not a valid school backup.');
}

/// The selected backup uses a newer database schema than this installation.
/// Restoring it would lose data, so it is refused.
class BackupSchemaIncompatibilityException extends BackupException {
  const BackupSchemaIncompatibilityException(int backupVersion, int currentVersion)
      : super(
          'This backup was created with a newer version of the app '
          '(schema $backupVersion) than the one installed '
          '(schema $currentVersion). Update the app before restoring it.',
        );
}

/// Raised when a write could not complete because storage is full or the
/// destination is read-only / permission-denied.
class BackupStorageException extends BackupException {
  const BackupStorageException(String detail)
      : super('Could not save the backup. $detail');
}

/// Raised when the live database cannot be closed, replaced or reopened during
/// restore. The original data is left untouched.
class BackupRestoreException extends BackupException {
  const BackupRestoreException(String detail)
      : super('Restore could not be completed. $detail');
}

/// Raised when a non-administrator attempts an admin-only backup/restore.
class BackupPermissionException extends BackupException {
  const BackupPermissionException()
      : super('Only the school administrator can perform this action.');
}
