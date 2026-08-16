import '../entities/backup_record.dart';

/// Outcome of a single backup action reported back to the UI.
class BackupResult {
  const BackupResult.success(this.record)
      : message = null,
        success = true;

  const BackupResult.failure(this.message)
      : record = null,
        success = false;

  final bool success;
  final BackupRecord? record;
  final String? message;

  @override
  String toString() =>
      success ? 'BackupResult(success, ${record?.filename})' : 'BackupResult($message)';
}
