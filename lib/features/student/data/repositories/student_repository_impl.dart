import 'package:sqflite/sqflite.dart';

import '../../../family/domain/entities/family.dart';
import '../../domain/entities/admission_history_entry.dart';
import '../../domain/entities/student.dart';
import '../../domain/entities/student_details.dart';
import '../../domain/entities/student_fee_history_item.dart';
import '../../domain/entities/student_history_entry.dart';
import '../../domain/entities/student_list_item.dart';
import '../../domain/repositories/student_repository.dart';

/// SQL implementation of [StudentRepository] over the `students`, `admissions`
/// and `student_history` tables. Foreign keys are enforced by the connection's
/// `PRAGMA foreign_keys = ON`, so a student can never reference a missing
/// family.
class StudentRepositoryImpl implements StudentRepository {
  StudentRepositoryImpl(this._db);

  final Database _db;

  static const String _studentPrefix = 'STU-';
  static const String _admissionPrefix = 'ADM-';
  static const int _idWidth = 6;

  @override
  Future<Student> createStudent({
    required int familyId,
    required String name,
    StudentGender? gender,
    DateTime? dateOfBirth,
    String? admissionNumber,
    DateTime? admissionDate,
    String? className,
    String? section,
    String? contactReference,
    String? notes,
    double admissionFee = 0,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Student name is required.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final effectiveAdmissionDate = admissionDate ?? DateTime.now();

    final rowId = await _db.transaction((txn) async {
      final studentId = await _nextId(
        txn,
        'students',
        'student_id',
        _studentPrefix,
      );
      final admissionId = await _nextId(
        txn,
        'admissions',
        'admission_id',
        _admissionPrefix,
      );
      final studentRowId = await txn.insert('students', {
        'student_id': studentId,
        'family_id': familyId,
        'name': trimmedName,
        'gender': gender?.name,
        'date_of_birth': _dateToIso(dateOfBirth),
        'class': _emptyToNull(className),
        'section': _emptyToNull(section),
        'admission_number': _emptyToNull(admissionNumber),
        'admission_date': _dateToIso(effectiveAdmissionDate),
        'contact_reference': _emptyToNull(contactReference),
        'notes': _emptyToNull(notes),
        'status': StudentStatus.active.dbValue,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('admissions', {
        'admission_id': admissionId,
        'student_id': studentRowId,
        'admission_number': _emptyToNull(admissionNumber),
        'admission_date': _dateToIso(effectiveAdmissionDate),
        'class': _emptyToNull(className),
        'section': _emptyToNull(section),
        'admission_fee': admissionFee,
        'notes': _emptyToNull(notes),
        'created_at': now,
      });
      return studentRowId;
    });
    return (await getStudent(rowId))!;
  }

  @override
  Future<Student> updateStudent({
    required int id,
    required int familyId,
    required String name,
    StudentGender? gender,
    DateTime? dateOfBirth,
    String? admissionNumber,
    DateTime? admissionDate,
    String? className,
    String? section,
    String? contactReference,
    String? notes,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Student name is required.');
    }
    final previous = await getStudent(id);
    if (previous == null) throw ArgumentError('Student $id does not exist.');

    final now = DateTime.now().toUtc().toIso8601String();
    await _db.transaction((txn) async {
      await txn.update(
        'students',
        {
          'family_id': familyId,
          'name': trimmedName,
          'gender': gender?.name,
          'date_of_birth': _dateToIso(dateOfBirth),
          'class': _emptyToNull(className),
          'section': _emptyToNull(section),
          'admission_number': _emptyToNull(admissionNumber),
          'admission_date': _dateToIso(admissionDate),
          'contact_reference': _emptyToNull(contactReference),
          'notes': _emptyToNull(notes),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (previous.className != _emptyToNull(className) ||
          previous.section != _emptyToNull(section)) {
        await _appendHistory(
          txn,
          id,
          className: className,
          section: section,
          status: previous.status.dbValue,
          now: now,
        );
      }
    });
    return (await getStudent(id))!;
  }

  @override
  Future<Student> setStudentStatus(int id, StudentStatus status) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.transaction((txn) async {
      await txn.update(
        'students',
        {'status': status.dbValue, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      final rows = await txn.query(
        'students',
        columns: ['class', 'section'],
        where: 'id = ?',
        whereArgs: [id],
      );
      await _appendHistory(
        txn,
        id,
        className: rows.first['class'] as String?,
        section: rows.first['section'] as String?,
        status: status.dbValue,
        now: now,
      );
    });
    return (await getStudent(id))!;
  }

  Future<void> _appendHistory(
    DatabaseExecutor txn,
    int studentId, {
    required String? className,
    required String? section,
    required String status,
    required String now,
  }) async {
    await txn.insert('student_history', {
      'student_id': studentId,
      'class': _emptyToNull(className),
      'section': _emptyToNull(section),
      'status': status,
      'changed_at': now,
      'created_at': now,
    });
  }

  @override
  Future<Student?> getStudent(int id) async {
    final rows = await _db.query('students', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<Student?> getStudentByStudentId(String studentId) async {
    final rows = await _db.query(
      'students',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<List<StudentListItem>> searchStudents({
    String query = '',
    StudentStatus? status,
    String? className,
    String? section,
    int limit = 100,
  }) async {
    final term = query.trim();
    final whereParts = <String>[];
    final args = <Object?>[];

    if (status != null) {
      whereParts.add('s.status = ?');
      args.add(status.dbValue);
    }
    if (className != null && className.trim().isNotEmpty) {
      whereParts.add('s.class = ?');
      args.add(className.trim());
    }
    if (section != null && section.trim().isNotEmpty) {
      whereParts.add('s.section = ?');
      args.add(section.trim());
    }

    if (term.isNotEmpty) {
      final q = '%$term%';
      final termConditions = <String>[
        's.student_id LIKE ?',
        's.name LIKE ?',
        "COALESCE(s.admission_number, '') LIKE ?",
        'f.family_id LIKE ?',
        'f.guardian_name LIKE ?',
        "COALESCE(f.phone, '') LIKE ?",
        "COALESCE(f.alternate_phone, '') LIKE ?",
      ];
      args.addAll(List.filled(7, q));
      final digits = _onlyDigits(term);
      if (digits.isNotEmpty) {
        final qd = '%$digits%';
        termConditions
          ..add('${_phoneDigits('f.phone')} LIKE ?')
          ..add('${_phoneDigits('f.alternate_phone')} LIKE ?');
        args.addAll(List.filled(2, qd));
      }
      whereParts.add('(${termConditions.join(' OR ')})');
    }

    final rows = await _db.rawQuery(
      '''
      SELECT s.*, f.family_id AS fam_id, f.guardian_name AS fam_guardian,
             f.phone AS fam_phone
      FROM students s
      JOIN families f ON f.id = s.family_id
      WHERE ${whereParts.isEmpty ? '1 = 1' : whereParts.join(' AND ')}
      ORDER BY s.student_id
      LIMIT ?
    ''',
      [...args, limit],
    );
    return rows.map(_toListItem).toList();
  }

  @override
  Future<StudentDetails> getStudentDetails(int id) async {
    final student = await getStudent(id);
    if (student == null) throw ArgumentError('Student $id does not exist.');

    final familyRows = await _db.query(
      'families',
      where: 'id = ?',
      whereArgs: [student.familyId],
    );
    final family = _familyFromRow(familyRows.first);

    final admissionRows = await _db.rawQuery(
      'SELECT id, admission_id, admission_date, class, section, '
      'admission_number, admission_fee, notes '
      'FROM admissions WHERE student_id = ? '
      'ORDER BY admission_date DESC, id DESC',
      [id],
    );
    final admissions = admissionRows.map((r) {
      return AdmissionHistoryEntry(
        id: _asInt(r['id']),
        admissionId: r['admission_id'] as String,
        admissionDate: _parseDate(r['admission_date']),
        className: r['class'] as String?,
        section: r['section'] as String?,
        admissionNumber: r['admission_number'] as String?,
        admissionFee: _asDouble(r['admission_fee']),
        notes: r['notes'] as String?,
      );
    }).toList();

    final historyRows = await _db.rawQuery(
      'SELECT id, class, section, status, changed_at '
      'FROM student_history WHERE student_id = ? '
      'ORDER BY changed_at DESC, id DESC',
      [id],
    );
    final history = historyRows.map((r) {
      return StudentHistoryEntry(
        id: _asInt(r['id']),
        className: r['class'] as String?,
        section: r['section'] as String?,
        status: r['status'] as String?,
        changedAt: _parseDate(r['changed_at']),
      );
    }).toList();

    final outstandingRows = await _db.rawQuery(
      'SELECT COALESCE(SUM(remaining_amount), 0) FROM fee_records '
      "WHERE status IN ('pending', 'partial') AND student_id = ?",
      [id],
    );
    final outstanding = _asDouble(outstandingRows.first.values.first);

    final feeRows = await _db.rawQuery(
      '''
      SELECT id, fee_record_id, period_start, period_end, expected_amount,
             discount, fine, net_payable, paid_amount, remaining_amount,
             status
      FROM fee_records
      WHERE student_id = ?
      ORDER BY period_start DESC, id DESC
    ''',
      [id],
    );
    final feeHistory = feeRows.map((r) {
      return StudentFeeHistoryItem(
        feeRecordId: _asInt(r['id']),
        feeRecordCode: r['fee_record_id'] as String,
        periodStart: _parseDate(r['period_start']),
        periodEnd: _parseDate(r['period_end']),
        expected: _asDouble(r['expected_amount']),
        paid: _asDouble(r['paid_amount']),
        status: r['status'] as String? ?? 'pending',
      );
    }).toList();

    return StudentDetails(
      student: student,
      family: family,
      admissions: admissions,
      history: history,
      outstandingFees: outstanding,
      feeHistory: feeHistory,
    );
  }

  @override
  Future<List<StudentListItem>> findPossibleStudentDuplicates({
    int? excludeId,
    required String name,
    String? admissionNumber,
    int? familyId,
    String? guardianName,
    String? primaryPhone,
  }) async {
    final nameValue = name.trim();
    if (nameValue.isEmpty) return const [];
    final nameCond = 'LOWER(TRIM(s.name)) = LOWER(TRIM(?))';

    // A student is flagged when ANY of the provided criteria matches; the
    // criteria are grouped with OR so e.g. a matching admission number is
    // enough on its own, and a name match only counts when the family,
    // phone or guardian also matches.
    final criteria = <String>[];
    final args = <Object?>[];

    final admission = admissionNumber?.trim() ?? '';
    if (admission.isNotEmpty) {
      criteria.add(
        "LOWER(TRIM(COALESCE(s.admission_number, ''))) = LOWER(TRIM(?))",
      );
      args.add(admission);
    }
    if (familyId != null) {
      criteria.add('($nameCond AND s.family_id = ?)');
      args
        ..add(nameValue)
        ..add(familyId);
    }
    final digits = _onlyDigits(primaryPhone ?? '');
    if (digits.isNotEmpty) {
      criteria.add(
        '($nameCond AND (${_phoneDigits('f.phone')} = ? '
        'OR ${_phoneDigits('f.alternate_phone')} = ?))',
      );
      args
        ..add(nameValue)
        ..add(digits)
        ..add(digits);
    }
    final guardian = guardianName?.trim() ?? '';
    if (guardian.isNotEmpty) {
      criteria.add(
        '($nameCond AND LOWER(TRIM(f.guardian_name)) = LOWER(TRIM(?)))',
      );
      args
        ..add(nameValue)
        ..add(guardian);
    }
    if (criteria.isEmpty) return const [];

    final where = [
      if (excludeId != null) 's.id != ?' else '1 = 1',
      '( ${criteria.join(' OR ')} )',
    ].join(' AND ');

    final rows = await _db.rawQuery(
      '''
      SELECT DISTINCT s.*, f.family_id AS fam_id, f.guardian_name AS fam_guardian,
             f.phone AS fam_phone
      FROM students s
      JOIN families f ON f.id = s.family_id
      WHERE $where
      ORDER BY s.student_id
    ''',
      [?excludeId, ...args],
    );
    return rows.map(_toListItem).toList();
  }

  @override
  @override
  Future<String> nextStudentId() =>
      _nextId(_db, 'students', 'student_id', _studentPrefix);

  @override
  Future<String> nextAdmissionId() =>
      _nextId(_db, 'admissions', 'admission_id', _admissionPrefix);

  @override
  Future<List<String>> distinctClasses() async {
    final rows = await _db.rawQuery(
      "SELECT DISTINCT class FROM students "
      "WHERE class IS NOT NULL AND class <> '' ORDER BY class",
    );
    return rows.map((r) => r['class'] as String).toList();
  }

  @override
  Future<List<String>> distinctSections() async {
    final rows = await _db.rawQuery(
      "SELECT DISTINCT section FROM students "
      "WHERE section IS NOT NULL AND section <> '' ORDER BY section",
    );
    return rows.map((r) => r['section'] as String).toList();
  }

  static Future<String> _nextId(
    DatabaseExecutor executor,
    String table,
    String column,
    String prefix,
  ) async {
    final row = await executor.rawQuery(
      'SELECT COALESCE(MAX(CAST(SUBSTR($column, ?) AS INTEGER)), 0) AS m '
      'FROM $table',
      [prefix.length + 1],
    );
    final maxValue = _asInt(row.first['m']);
    return '$prefix${(maxValue + 1).toString().padLeft(_idWidth, '0')}';
  }

  static String? _emptyToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _dateToIso(DateTime? value) => value?.toIso8601String();

  static String _onlyDigits(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  static String _phoneDigits(String column) {
    return "REPLACE(REPLACE(REPLACE(COALESCE($column, ''), ' ', ''), '-', ''), '+', '')";
  }

  static StudentListItem _toListItem(Map<String, Object?> row) {
    return StudentListItem(
      student: _fromRow(row),
      familyId: row['fam_id'] as String? ?? '',
      guardianName: row['fam_guardian'] as String?,
      guardianPhone: row['fam_phone'] as String?,
    );
  }

  static Student _fromRow(Map<String, Object?> row) {
    return Student(
      id: _asInt(row['id']),
      studentId: row['student_id'] as String,
      familyId: _asInt(row['family_id']),
      name: row['name'] as String,
      gender: row['gender'] == null
          ? null
          : StudentGender.fromDb(row['gender'] as String),
      dateOfBirth: _parseDateOrNull(row['date_of_birth']),
      admissionNumber: row['admission_number'] as String?,
      admissionDate: _parseDateOrNull(row['admission_date']),
      className: row['class'] as String?,
      section: row['section'] as String?,
      contactReference: row['contact_reference'] as String?,
      notes: row['notes'] as String?,
      status: StudentStatus.fromDb(row['status'] as String?),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  static Family _familyFromRow(Map<String, Object?> row) {
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

  static DateTime? _parseDateOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String)?.toLocal();
  }

  static int _asInt(Object? value) => (value as num?)?.toInt() ?? 0;

  static double _asDouble(Object? value) => (value as num?)?.toDouble() ?? 0;
}
