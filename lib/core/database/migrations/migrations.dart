import 'migration.dart';
import 'migration_v1.dart';
import 'migration_v2.dart';
import 'migration_v3.dart';
import 'migration_v4.dart';
import 'migration_v5.dart';
import 'migration_v6.dart';
import 'migration_v7.dart';
import 'migration_v8.dart';
import 'migration_v9.dart';
import 'migration_v10.dart';
import 'migration_v11.dart';
import 'migration_v12.dart';
import 'migration_v13.dart';
import 'migration_v14.dart';

/// All migrations in apply order. Append new migrations here.
const List<Migration> migrations = [
  migrationV1,
  migrationV2,
  migrationV3,
  migrationV4,
  migrationV5,
  migrationV6,
  migrationV7,
  migrationV8,
  migrationV9,
  migrationV10,
  migrationV11,
  migrationV12,
  migrationV13,
  migrationV14,
];
