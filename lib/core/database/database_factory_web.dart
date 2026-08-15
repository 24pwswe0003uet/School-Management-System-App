import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Browser SQLite backend (sqlite3 compiled to WASM, runs in a shared worker).
void initDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}
