import 'package:sqflite/sqflite.dart';

import '../../domain/entities/family.dart';
import '../../domain/entities/family_details.dart';
import '../../domain/entities/family_list_item.dart';
import '../../domain/entities/family_student.dart';
import '../../domain/repositories/family_has_linked_students_exception.dart';
import '../../domain/repositories/family_repository.dart';

/// SQL implementation of [FamilyRepository] over the `families` and `students`
/// tables. Foreign keys are enforced by the connection's `PRAGMA foreign_keys
/// = ON`, so orphan students are impossible.
class FamilyRepositoryImpl implements FamilyRepository {
  FamilyRepositoryImpl(this._db);

  final Database _db;

  static const String _idPrefix = 'FAM-';
  static const int _idWidth = 6;

  @override
  Future<Family> createFamily({
    required String guardianName,
    String? motherName,
    String? primaryPhone,
    String? secondaryPhone,
    String? address,
    String? cnic,
    String? notes,
  }) async {
    _requireGuardian(guardianName);
    final familyId = await nextFamilyId();
    final now = DateTime.now().toUtc().toIso8601String();
    final id = await _db.insert('families', {
      'family_id': familyId,
      'guardian_name': guardianName.trim(),
      'mother_name': _emptyToNull(motherName),
      'phone': _emptyToNull(primaryPhone),
      'alternate_phone': _emptyToNull(secondaryPhone),
      'address': _emptyToNull(address),
      'cnic': _emptyToNull(cnic == null ? null : normalizeCnic(cnic)),
      'notes': _emptyToNull(notes),
      'status': 'active',
      'created_at': now,
      'updated_at': now,
    });
    return (await getFamily(id))!;
  }

  @override
  Future<Family> updateFamily({
    required int id,
    required String guardianName,
    String? motherName,
    String? primaryPhone,
    String? secondaryPhone,
    String? address,
    String? cnic,
    String? notes,
  }) async {
    _requireGuardian(guardianName);
    await _db.update(
      'families',
      {
        'guardian_name': guardianName.trim(),
        'mother_name': _emptyToNull(motherName),
        'phone': _emptyToNull(primaryPhone),
        'alternate_phone': _emptyToNull(secondaryPhone),
        'address': _emptyToNull(address),
        'cnic': _emptyToNull(cnic == null ? null : normalizeCnic(cnic)),
        'notes': _emptyToNull(notes),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return (await getFamily(id))!;
  }

  @override
  Future<Family> archiveFamily(int id) async {
    await _setStatus(id, 'inactive');
    return (await getFamily(id))!;
  }

  @override
  Future<Family> unarchiveFamily(int id) async {
    await _setStatus(id, 'active');
    return (await getFamily(id))!;
  }

  Future<void> _setStatus(int id, String status) async {
    await _db.update(
      'families',
      {
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteFamily(int id) async {
    final family = await getFamily(id);
    if (family == null) return;
    final linked = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM students WHERE family_id = ?', [
        id,
      ]),
    );
    if (linked != null && linked > 0) {
      throw FamilyHasLinkedStudentsException(family.familyId);
    }
    await _db.delete('families', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Family?> getFamily(int id) async {
    final rows = await _db.query('families', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<Family?> getFamilyByFamilyId(String familyId) async {
    final rows = await _db.query(
      'families',
      where: 'family_id = ?',
      whereArgs: [familyId],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<List<FamilyListItem>> searchFamilies(
    String query, {
    int limit = 50,
  }) async {
    final term = query.trim();
    if (term.isEmpty) {
      final rows = await _db.query(
        'families',
        orderBy: 'family_id',
        limit: limit,
      );
      return rows.map((r) {
        return FamilyListItem(family: _fromRow(r), studentCount: 0);
      }).toList();
    }

    final conditions = <String>[];
    final args = <Object?>[];

    final q = '%$term%';
    conditions
      ..add('f.family_id LIKE ?')
      ..add('f.guardian_name LIKE ?')
      ..add("COALESCE(f.mother_name, '') LIKE ?")
      ..add("COALESCE(f.phone, '') LIKE ?")
      ..add("COALESCE(f.alternate_phone, '') LIKE ?")
      ..add('s.name LIKE ?');
    args.addAll(List.filled(6, q));

    final digits = _onlyDigits(term);
    if (digits.isNotEmpty) {
      final qd = '%$digits%';
      conditions
        ..add('${_phoneDigits('f.phone')} LIKE ?')
        ..add('${_phoneDigits('f.alternate_phone')} LIKE ?');
      args.addAll(List.filled(2, qd));
    }

    final rows = await _db.rawQuery(
      '''
      SELECT DISTINCT f.*,
        (SELECT COUNT(*) FROM students s WHERE s.family_id = f.id)
          AS student_count
      FROM families f
      LEFT JOIN students s ON s.family_id = f.id
      WHERE ${conditions.join(' OR ')}
      ORDER BY f.family_id
      LIMIT ?
    ''',
      [...args, limit],
    );
    return rows.map((r) {
      return FamilyListItem(
        family: _fromRow(r),
        studentCount: _asInt(r['student_count']),
      );
    }).toList();
  }

  @override
  Future<List<Family>> findPossibleDuplicates({
    int? excludeId,
    String? guardianName,
    String? motherName,
    String? primaryPhone,
    String? secondaryPhone,
    String? address,
  }) async {
    final guardian = _normalized(guardianName);
    final mother = _normalized(motherName);
    final phone1 = _onlyDigits(primaryPhone ?? '');
    final phone2 = _onlyDigits(secondaryPhone ?? '');
    final addressQuery = _normalized(address);

    final conditions = <String>[];
    final args = <Object?>[];

    if (guardian.isNotEmpty) {
      conditions.add('LOWER(TRIM(f.guardian_name)) LIKE ?');
      args.add('%$guardian%');
    }
    if (mother.isNotEmpty) {
      conditions.add('LOWER(TRIM(COALESCE(f.mother_name, \'\'))) LIKE ?');
      args.add('%$mother%');
    }
    if (phone1.isNotEmpty) {
      conditions.add('${_phoneDigits('f.phone')} = ?');
      args.add(phone1);
    }
    if (phone2.isNotEmpty) {
      conditions.add('${_phoneDigits('f.alternate_phone')} = ?');
      args.add(phone2);
    }
    if (addressQuery.isNotEmpty) {
      conditions.add('LOWER(COALESCE(f.address, \'\')) LIKE ?');
      args.add('%$addressQuery%');
    }
    if (conditions.isEmpty) return const [];

    final where = [
      if (excludeId != null) 'f.id != ?' else '1 = 1',
      ...conditions,
    ].join(' AND ');

    final rows = await _db.rawQuery(
      'SELECT DISTINCT f.* FROM families f WHERE $where ORDER BY f.family_id',
      [?excludeId, ...args],
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<FamilyDetails> getFamilyDetails(int id) async {
    final family = await getFamily(id);
    if (family == null) {
      throw ArgumentError('Family $id does not exist.');
    }

    final studentRows = await _db.rawQuery(
      'SELECT id, student_id, name, class, section, status '
      'FROM students WHERE family_id = ? ORDER BY name',
      [id],
    );
    final students = studentRows.map((r) {
      return FamilyStudent(
        id: _asInt(r['id']),
        studentId: r['student_id'] as String,
        name: r['name'] as String,
        className: r['class'] as String?,
        section: r['section'] as String?,
        status: r['status'] as String? ?? 'active',
      );
    }).toList();

    final rows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(fr.remaining_amount), 0)
      FROM fee_records fr
      JOIN students s ON s.id = fr.student_id
      WHERE fr.status IN ('pending', 'partial') AND s.family_id = ?
    ''',
      [id],
    );
    final outstanding = _asDouble(rows.first.values.first);

    return FamilyDetails(
      family: family,
      students: students,
      outstandingFees: outstanding,
    );
  }

  @override
  Future<String> nextFamilyId() async {
    final row = await _db.rawQuery(
      'SELECT COALESCE(MAX(CAST(SUBSTR(family_id, ?) AS INTEGER)), 0) AS m '
      'FROM families',
      [_idPrefix.length + 1],
    );
    final maxValue = _asInt(row.first['m']);
    return '$_idPrefix${(maxValue + 1).toString().padLeft(_idWidth, '0')}';
  }

  static void _requireGuardian(String guardianName) {
    if (guardianName.trim().isEmpty) {
      throw ArgumentError('Guardian name is required.');
    }
  }

  static String? _emptyToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _normalized(String? value) {
    if (value == null) return '';
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _onlyDigits(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  /// Normalizes a CNIC to the display format `XXXXX-XXXXXXX-X`. Accepts 13
  /// raw digits or digits separated by dashes.
  static String? normalizeCnic(String value) {
    final digits = _onlyDigits(value);
    if (digits.length != 13) return _emptyToNull(value);
    return '${digits.substring(0, 5)}-${digits.substring(5, 12)}-'
        '${digits.substring(12)}';
  }

  /// SQL expression yielding the digits-only form of a phone column, so a
  /// query for `0300-1234567` matches a stored `03001234567`.
  static String _phoneDigits(String column) {
    return "REPLACE(REPLACE(REPLACE(COALESCE($column, ''), ' ', ''), '-', ''), '+', '')";
  }

  static Family _fromRow(Map<String, Object?> row) {
    return Family(
      id: _asInt(row['id']),
      familyId: row['family_id'] as String,
      guardianName: row['guardian_name'] as String,
      motherName: row['mother_name'] as String?,
      primaryPhone: row['phone'] as String?,
      secondaryPhone: row['alternate_phone'] as String?,
      address: row['address'] as String?,
      cnic: row['cnic'] as String?,
      notes: row['notes'] as String?,
      status: FamilyStatus.fromDb(row['status'] as String? ?? 'active'),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  static DateTime _parseDate(Object? value) =>
      DateTime.tryParse(value as String)?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  static int _asInt(Object? value) => (value as num?)?.toInt() ?? 0;

  static double _asDouble(Object? value) => (value as num?)?.toDouble() ?? 0;
}
