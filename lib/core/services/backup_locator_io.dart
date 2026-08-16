import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'backup_locator.dart';

/// Default [BackupLocator] for platforms with a filesystem (Windows, Linux,
/// macOS). Reads/writes only inside the application-support directory so no
/// hard-coded paths are ever used.
class IoBackupLocator implements BackupLocator {
  @override
  Future<String> backupDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  @override
  Future<bool> openDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return false;
    final String command;
    switch (Platform.operatingSystem) {
      case 'windows':
        command = 'explorer.exe';
      case 'macos':
        command = 'open';
      case 'linux':
        command = 'xdg-open';
      default:
        return false;
    }
    try {
      await Process.run(command, [path]);
      return true;
    } catch (_) {
      try {
        await Process.start(command, [path]);
        return true;
      } catch (_) {
        return false;
      }
    }
  }
}

/// Public factory mirroring the logo-store pattern so the concrete locator is
/// swapped at compile time for the web (no `dart:io`) build.
BackupLocator createBackupLocator() => IoBackupLocator();
