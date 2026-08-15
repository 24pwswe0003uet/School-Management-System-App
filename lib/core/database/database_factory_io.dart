import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Native (Windows/Linux/macOS) SQLite backend.
void initDatabaseFactory() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
