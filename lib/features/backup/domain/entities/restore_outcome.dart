/// Outcome of a restore operation, reported back to the UI.
class RestoreOutcome {
  const RestoreOutcome.success({
    required this.safetyBackup,
    required this.version,
  })  : message = null,
        success = true;

  const RestoreOutcome.failure(this.message)
      : success = false,
        safetyBackup = null,
        version = 0;

  final bool success;
  final String? message;

  /// Path to the safety backup created before the live database was replaced.
  final String? safetyBackup;

  /// Schema version of the restored database.
  final int version;
}
