import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../domain/entities/school_class.dart';
import '../../domain/entities/school_profile.dart';
import '../../domain/entities/school_section.dart';
import '../../domain/repositories/settings_repository.dart';

/// SQLite-backed [SettingsRepository].
///
/// The profile and logo metadata live in the `app_settings` key/value table;
/// the logo image itself lives on disk via [LogoStore] (or as a BLOB in the
/// `school_logo` table when file storage is unavailable, e.g. web). Canonical
/// class/section lists live in their own tables seeded by migration V12.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._db, this._logoStore);

  final Database _db;
  final LogoStore _logoStore;

  // Profile -----------------------------------------------------------------

  @override
  Future<SchoolProfile> getProfile() async {
    final rows = await _db.query('app_settings');
    final map = <String, String>{
      for (final row in rows)
        row['key'] as String: row['value'] as String? ?? '',
    };
    return SchoolProfile(
      schoolName: map['school_name'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      academicYear: map['academic_year'] ?? '',
      receiptFooter: map['receipt_footer'] ?? '',
      logoKind: LogoKind.fromValue(map['logo_kind']),
      logoFileName: map['logo_file_name'] == ''
          ? null
          : map['logo_file_name'],
      logoMimeType: map['logo_mime_type'] == ''
          ? null
          : map['logo_mime_type'],
    );
  }

  @override
  Future<SchoolProfile> saveProfile({
    required String schoolName,
    String address = '',
    String phone = '',
    String email = '',
    String academicYear = '',
    String receiptFooter = '',
  }) async {
    await _db.transaction((txn) async {
      await _set(txn, 'school_name', schoolName);
      await _set(txn, 'address', address);
      await _set(txn, 'phone', phone);
      await _set(txn, 'email', email);
      await _set(txn, 'academic_year', academicYear);
      await _set(txn, 'receipt_footer', receiptFooter);
    });
    return getProfile();
  }

  @override
  Future<SchoolProfile> updateLogo({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final fileName = _fileNameFor(mimeType);
    try {
      await _logoStore.write(bytes: bytes, mimeType: mimeType);
      await _clearBlobLogo();
      await _set(_db, 'logo_kind', LogoKind.file.value);
      await _set(_db, 'logo_mime_type', mimeType);
      await _set(_db, 'logo_file_name', fileName);
    } catch (_) {
      // No file system (web) or a file write failure — fall back to storing
      // the image as a BLOB in SQLite.
      await _db.transaction((txn) async {
        await txn.delete('school_logo');
        await txn.insert('school_logo', {
          'mime_type': mimeType,
          'data': bytes,
          'updated_at': _now(),
        });
      });
      await _set(_db, 'logo_kind', LogoKind.blob.value);
      await _set(_db, 'logo_mime_type', mimeType);
      await _set(_db, 'logo_file_name', fileName);
    }
    return getProfile();
  }

  @override
  Future<SchoolProfile> removeLogo() async {
    try {
      await _logoStore.remove();
    } catch (_) {
      // No file system (web) — nothing to remove; the BLOB and metadata below
      // are still cleared.
    }
    await _clearBlobLogo();
    await _set(_db, 'logo_kind', LogoKind.none.value);
    await _set(_db, 'logo_mime_type', '');
    await _set(_db, 'logo_file_name', '');
    return getProfile();
  }

  @override
  Future<Uint8List?> getLogoBytes() async {
    final kind = LogoKind.fromValue(await _get(_db, 'logo_kind'));
    if (kind == LogoKind.blob) {
      final rows = await _db.query('school_logo', limit: 1);
      if (rows.isEmpty) return null;
      final data = rows.first['data'];
      return data is Uint8List ? data : null;
    }
    if (kind == LogoKind.file) {
      return _logoStore.read();
    }
    return null;
  }

  Future<void> _clearBlobLogo() async {
    await _db.delete('school_logo');
  }

  // Classes ------------------------------------------------------------------

  @override
  Future<List<SchoolClass>> listClasses({
    bool includeInactive = false,
  }) async {
    final where = includeInactive ? '' : 'WHERE c.is_active = 1';
    final rows = await _db.rawQuery('''
      SELECT c.id, c.class_name, c.is_active, c.created_at, c.updated_at,
             (SELECT COUNT(*) FROM students s
              WHERE s.class = c.class_name AND s.status = 'active')
             AS active_student_count
      FROM academic_classes c
      $where
      ORDER BY c.class_name COLLATE NOCASE
    ''');
    return rows.map(_classFromRow).toList();
  }

  @override
  Future<SchoolClass> addClass(String className) async {
    final now = _now();
    try {
      final id = await _db.insert('academic_classes', {
        'class_name': className.trim(),
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      return (await _findClass(id))!;
    } on DatabaseException catch (e) {
      if (_isConstraintError(e)) {
        throw DuplicateSettingsNameException('Class', className.trim());
      }
      rethrow;
    }
  }

  @override
  Future<SchoolClass> updateClass({
    required int id,
    required String className,
    bool renameStudents = false,
  }) async {
    final now = _now();
    try {
      await _db.transaction((txn) async {
        if (renameStudents) {
          final old = await _classRow(txn, id);
          if (old != null) {
            await txn.update(
              'students',
              {'class': className.trim(), 'updated_at': now},
              where: 'class = ?',
              whereArgs: [old['class_name']],
            );
          }
        }
        await txn.update(
          'academic_classes',
          {'class_name': className.trim(), 'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      return (await _findClass(id))!;
    } on DatabaseException catch (e) {
      if (_isConstraintError(e)) {
        throw DuplicateSettingsNameException('Class', className.trim());
      }
      rethrow;
    }
  }

  @override
  Future<void> setClassActive(int id, bool isActive) async {
    await _db.update(
      'academic_classes',
      {'is_active': isActive ? 1 : 0, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, Object?>?> _classRow(
    DatabaseExecutor executor,
    int id,
  ) async {
    final rows = await executor.query(
      'academic_classes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<SchoolClass?> _findClass(int id) async {
    final rows = await _db.rawQuery('''
      SELECT c.id, c.class_name, c.is_active, c.created_at, c.updated_at,
             (SELECT COUNT(*) FROM students s
              WHERE s.class = c.class_name AND s.status = 'active')
             AS active_student_count
      FROM academic_classes c
      WHERE c.id = ?
    ''', [id]);
    return rows.isEmpty ? null : _classFromRow(rows.first);
  }

  SchoolClass _classFromRow(Map<String, Object?> row) => SchoolClass(
        id: row['id'] as int,
        className: row['class_name'] as String,
        isActive: (row['is_active'] as int) == 1,
        createdAt: _parse(row['created_at']),
        updatedAt: _parse(row['updated_at']),
        activeStudentCount: (row['active_student_count'] as int?) ?? 0,
      );

  // Sections ------------------------------------------------------------------

  @override
  Future<List<SchoolSection>> listSections({
    bool includeInactive = false,
  }) async {
    final where = includeInactive ? '' : 'WHERE s.is_active = 1';
    final rows = await _db.rawQuery('''
      SELECT s.id, s.section_name, s.is_active, s.created_at, s.updated_at,
             (SELECT COUNT(*) FROM students st
              WHERE st.section = s.section_name AND st.status = 'active')
             AS active_student_count
      FROM academic_sections s
      $where
      ORDER BY s.section_name COLLATE NOCASE
    ''');
    return rows.map(_sectionFromRow).toList();
  }

  @override
  Future<SchoolSection> addSection(String sectionName) async {
    final now = _now();
    try {
      final id = await _db.insert('academic_sections', {
        'section_name': sectionName.trim(),
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      final rows = await _db.query(
        'academic_sections',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return _sectionFromRow(rows.first);
    } on DatabaseException catch (e) {
      if (_isConstraintError(e)) {
        throw DuplicateSettingsNameException('Section', sectionName.trim());
      }
      rethrow;
    }
  }

  @override
  Future<SchoolSection> updateSection({
    required int id,
    required String sectionName,
    bool renameStudents = false,
  }) async {
    final now = _now();
    try {
      await _db.transaction((txn) async {
        if (renameStudents) {
          final rows = await txn.query(
            'academic_sections',
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          if (rows.isNotEmpty) {
            await txn.update(
              'students',
              {'section': sectionName.trim(), 'updated_at': now},
              where: 'section = ?',
              whereArgs: [rows.first['section_name']],
            );
          }
        }
        await txn.update(
          'academic_sections',
          {'section_name': sectionName.trim(), 'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      final rows = await _db.query(
        'academic_sections',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return _sectionFromRow(rows.first);
    } on DatabaseException catch (e) {
      if (_isConstraintError(e)) {
        throw DuplicateSettingsNameException('Section', sectionName.trim());
      }
      rethrow;
    }
  }

  @override
  Future<void> setSectionActive(int id, bool isActive) async {
    await _db.update(
      'academic_sections',
      {'is_active': isActive ? 1 : 0, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  SchoolSection _sectionFromRow(Map<String, Object?> row) => SchoolSection(
        id: row['id'] as int,
        sectionName: row['section_name'] as String,
        isActive: (row['is_active'] as int) == 1,
        createdAt: _parse(row['created_at']),
        updatedAt: _parse(row['updated_at']),
        activeStudentCount: (row['active_student_count'] as int?) ?? 0,
      );

  // Helpers ------------------------------------------------------------------

  static Future<void> _set(
    DatabaseExecutor executor,
    String key,
    String value,
  ) async {
    await executor.insert(
      'app_settings',
      {'key': key, 'value': value, 'updated_at': _now()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> _get(DatabaseExecutor executor, String key) async {
    final rows = await executor.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  static String _fileNameFor(String mimeType) =>
      'school_logo.${switch (mimeType) {
        'image/png' => 'png',
        'image/jpeg' => 'jpg',
        _ => 'bin',
      }}';

  static bool _isConstraintError(DatabaseException e) =>
      e.isUniqueConstraintError();

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static DateTime _parse(Object? value) {
    final parsed = DateTime.tryParse(value as String? ?? '');
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}
