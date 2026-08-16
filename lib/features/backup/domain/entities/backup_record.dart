import 'package:flutter/foundation.dart';

/// Health of a completed backup operation.
enum BackupStatus {
  /// The backup file was created and verified successfully.
  successful,

  /// The file exists but could not be verified (corrupt / unreadable).
  failed,

  /// The file is no longer on disk.
  missing,
}

@immutable
class BackupRecord {
  const BackupRecord({
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
    required this.schemaVersion,
    required this.status,
  });

  /// Absolute path to the backup file.
  final String path;

  /// When the backup was taken. Encoded in the filename as well.
  final DateTime createdAt;

  /// File size in bytes (0 when missing).
  final int sizeBytes;

  /// `PRAGMA user_version` (i.e. the app schema version) the backup was made on.
  final int schemaVersion;

  /// Verification status at the time the record was listed.
  final BackupStatus status;

  String get filename => path.split('/').last.split('\\').last;

  String get directory => path.substring(0, path.length - filename.length - 1);

  @override
  String toString() => 'BackupRecord($filename, status=$status)';
}
