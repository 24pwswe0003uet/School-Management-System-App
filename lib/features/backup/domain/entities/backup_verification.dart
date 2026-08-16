import '../entities/backup_record.dart';

/// Outcome of verifying a database file (a freshly created backup or the
/// live database after a restore).
class BackupVerification {
  const BackupVerification({
    required this.exists,
    required this.sizeBytes,
    required this.readable,
    required this.integrityOk,
    required this.tablesPresent,
    required this.schemaVersion,
    this.errorMessage,
  });

  final bool exists;
  final int sizeBytes;
  final bool readable;
  final bool integrityOk;
  final bool tablesPresent;
  final int schemaVersion;
  final String? errorMessage;

  bool get isOk =>
      exists &&
      sizeBytes > 0 &&
      readable &&
      integrityOk &&
      tablesPresent;

  factory BackupVerification.failed(String reason) => BackupVerification(
        exists: false,
        sizeBytes: 0,
        readable: false,
        integrityOk: false,
        tablesPresent: false,
        schemaVersion: 0,
        errorMessage: reason,
      );

  BackupRecord toRecord(DateTime createdAt, BackupStatus status) => BackupRecord(
        path: '',
        createdAt: createdAt,
        sizeBytes: sizeBytes,
        schemaVersion: schemaVersion,
        status: status,
      );

  @override
  String toString() => 'BackupVerification('
      'exists=$exists, readable=$readable, integrity=$integrityOk, '
      'tables=$tablesPresent, version=$schemaVersion, error=$errorMessage)';
}
