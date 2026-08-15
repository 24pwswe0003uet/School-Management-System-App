import 'package:sqflite/sqflite.dart';

import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_category.dart';
import '../../domain/entities/employee_details.dart';
import '../../domain/entities/employee_salary_record.dart';
import '../../domain/entities/employee_status.dart';
import '../../domain/repositories/employee_has_salary_history_exception.dart';
import '../../domain/repositories/employee_repository.dart';

/// SQL implementation of [EmployeeRepository] over the `employees` and
/// `salary_records` tables. Foreign keys are enforced by the connection's
/// `PRAGMA foreign_keys = ON`, so a salary record can never reference a
/// missing employee.
class EmployeeRepositoryImpl implements EmployeeRepository {
  EmployeeRepositoryImpl(this._db);

  final Database _db;

  static const String _idPrefix = 'EMP-';
  static const int _idWidth = 6;

  @override
  Future<Employee> createEmployee({
    required String name,
    required String designation,
    required EmployeeCategory category,
    String? department,
    String? phone,
    String? address,
    String? cnic,
    DateTime? joiningDate,
    double basicSalary = 0,
    String? notes,
  }) async {
    _requireFields(name: name, designation: designation);
    _requireNonNegative(basicSalary);
    final employeeId = await nextEmployeeId();
    final now = DateTime.now().toUtc().toIso8601String();
    final id = await _db.insert('employees', {
      'employee_id': employeeId,
      'name': name.trim(),
      'designation': designation.trim(),
      'category': category.dbValue,
      'department': _emptyToNull(department),
      'contact': _emptyToNull(phone),
      'address': _emptyToNull(address),
      'cnic': _emptyToNull(cnic == null ? null : normalizeCnic(cnic)),
      'joining_date': _dateToIso(joiningDate),
      'basic_salary': basicSalary,
      'notes': _emptyToNull(notes),
      'status': EmployeeStatus.active.dbValue,
      'created_at': now,
      'updated_at': now,
    });
    return (await getEmployee(id))!;
  }

  @override
  Future<Employee> updateEmployee({
    required int id,
    required String name,
    required String designation,
    required EmployeeCategory category,
    String? department,
    String? phone,
    String? address,
    String? cnic,
    DateTime? joiningDate,
    double basicSalary = 0,
    String? notes,
  }) async {
    _requireFields(name: name, designation: designation);
    _requireNonNegative(basicSalary);
    await _db.update(
      'employees',
      {
        'name': name.trim(),
        'designation': designation.trim(),
        'category': category.dbValue,
        'department': _emptyToNull(department),
        'contact': _emptyToNull(phone),
        'address': _emptyToNull(address),
        'cnic': _emptyToNull(cnic == null ? null : normalizeCnic(cnic)),
        'joining_date': _dateToIso(joiningDate),
        'basic_salary': basicSalary,
        'notes': _emptyToNull(notes),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return (await getEmployee(id))!;
  }

  @override
  Future<Employee> deactivateEmployee(int id) =>
      _setStatus(id, EmployeeStatus.inactive);

  @override
  Future<Employee> reactivateEmployee(int id) =>
      _setStatus(id, EmployeeStatus.active);

  Future<Employee> _setStatus(int id, EmployeeStatus status) async {
    await _db.update(
      'employees',
      {
        'status': status.dbValue,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return (await getEmployee(id))!;
  }

  @override
  Future<void> deleteEmployee(int id) async {
    final employee = await getEmployee(id);
    if (employee == null) return;
    final linked = Sqflite.firstIntValue(
      await _db.rawQuery(
        'SELECT COUNT(*) FROM salary_records WHERE employee_id = ?',
        [id],
      ),
    );
    if (linked != null && linked > 0) {
      throw EmployeeHasSalaryHistoryException(employee.employeeId);
    }
    await _db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Employee?> getEmployee(int id) async {
    final rows = await _db.query(
      'employees',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<Employee?> getEmployeeByEmployeeId(String employeeId) async {
    final rows = await _db.query(
      'employees',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<List<Employee>> searchEmployees(
    String query, {
    EmployeeCategory? category,
    EmployeeStatus? status,
    int limit = 50,
  }) async {
    final whereParts = <String>[];
    final args = <Object?>[];

    if (category != null) {
      whereParts.add('category = ?');
      args.add(category.dbValue);
    }
    if (status != null) {
      whereParts.add('status = ?');
      args.add(status.dbValue);
    }

    final term = query.trim();
    if (term.isNotEmpty) {
      final q = '%$term%';
      final conditions = <String>[
        'employee_id LIKE ?',
        'name LIKE ?',
        "COALESCE(designation, '') LIKE ?",
        "COALESCE(contact, '') LIKE ?",
      ];
      args.addAll(List.filled(4, q));

      final digits = _onlyDigits(term);
      if (digits.isNotEmpty) {
        final qd = '%$digits%';
        conditions.add('${_phoneDigits('contact')} LIKE ?');
        args.add(qd);
      }
      whereParts.add('(${conditions.join(' OR ')})');
    }

    final rows = await _db.rawQuery(
      '''
      SELECT * FROM employees
      WHERE ${whereParts.isEmpty ? '1 = 1' : whereParts.join(' AND ')}
      ORDER BY employee_id
      LIMIT ?
    ''',
      [...args, limit],
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Employee>> findPossibleDuplicates({
    int? excludeId,
    String? name,
    String? phone,
    String? cnic,
  }) async {
    final trimmedName = name?.trim() ?? '';
    final digits = _onlyDigits(phone ?? '');
    final normalizedCnic = cnic == null ? null : normalizeCnic(cnic.trim());
    final cnicValue = _emptyToNull(normalizedCnic);

    final criteria = <String>[];
    final args = <Object?>[];

    final nameCond = 'LOWER(TRIM(e.name)) = LOWER(TRIM(?))';

    // A phone or CNIC match alone is a strong signal; a name match only counts
    // when a phone or CNIC also matches (same name with a different phone is
    // explicitly allowed by the specification).
    if (digits.isNotEmpty) {
      criteria.add('${_phoneDigits('e.contact')} = ?');
      args.add(digits);
    }
    if (cnicValue != null) {
      criteria.add("LOWER(TRIM(COALESCE(e.cnic, ''))) = LOWER(TRIM(?))");
      args.add(cnicValue);
    }
    if (trimmedName.isNotEmpty) {
      if (digits.isNotEmpty) {
        criteria.add('($nameCond AND ${_phoneDigits('e.contact')} = ?)');
        args
          ..add(trimmedName)
          ..add(digits);
      }
      if (cnicValue != null) {
        criteria.add(
          "($nameCond AND LOWER(TRIM(COALESCE(e.cnic, ''))) = LOWER(TRIM(?)))",
        );
        args
          ..add(trimmedName)
          ..add(cnicValue);
      }
    }
    if (criteria.isEmpty) return const [];

    final where = [
      if (excludeId != null) 'e.id != ?' else '1 = 1',
      '( ${criteria.join(' OR ')} )',
    ].join(' AND ');

    final rows = await _db.rawQuery(
      '''
      SELECT DISTINCT e.* FROM employees e
      WHERE $where
      ORDER BY e.employee_id
    ''',
      [?excludeId, ...args],
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<EmployeeDetails> getEmployeeDetails(int id) async {
    final employee = await getEmployee(id);
    if (employee == null) {
      throw ArgumentError('Employee $id does not exist.');
    }

    final salaryRows = await _db.rawQuery(
      'SELECT id, period_start, period_end, base_salary, advance, deduction, '
      'net_amount, payment_date, status '
      'FROM salary_records WHERE employee_id = ? '
      'ORDER BY period_start DESC, id DESC',
      [id],
    );
    final history = salaryRows.map((r) {
      return EmployeeSalaryRecord(
        id: _asInt(r['id']),
        periodStart: _parseDate(r['period_start']),
        periodEnd: _parseDate(r['period_end']),
        baseSalary: _asDouble(r['base_salary']),
        advance: _asDouble(r['advance']),
        deduction: _asDouble(r['deduction']),
        netAmount: _asDouble(r['net_amount']),
        paymentDate: _parseDateOrNull(r['payment_date']),
        status: SalaryStatus.fromDb(r['status'] as String? ?? 'pending'),
      );
    }).toList();

    var totalPaid = 0.0;
    var totalPending = 0.0;
    for (final record in history) {
      if (record.status == SalaryStatus.paid) {
        totalPaid += record.netAmount;
      } else {
        totalPending += record.netAmount;
      }
    }

    return EmployeeDetails(
      employee: employee,
      salaryHistory: history,
      totalPaid: totalPaid,
      totalPending: totalPending,
    );
  }

  @override
  Future<String> nextEmployeeId() async {
    final row = await _db.rawQuery(
      'SELECT COALESCE(MAX(CAST(SUBSTR(employee_id, ?) AS INTEGER)), 0) AS m '
      'FROM employees',
      [_idPrefix.length + 1],
    );
    final maxValue = _asInt(row.first['m']);
    return '$_idPrefix${(maxValue + 1).toString().padLeft(_idWidth, '0')}';
  }

  static void _requireFields({required String name, required String designation}) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Employee name is required.');
    }
    if (designation.trim().isEmpty) {
      throw ArgumentError('Designation is required.');
    }
  }

  static void _requireNonNegative(double value) {
    if (value < 0) {
      throw ArgumentError('Basic salary cannot be negative.');
    }
  }

  static String? _emptyToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _dateToIso(DateTime? value) => value?.toIso8601String();

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

  static Employee _fromRow(Map<String, Object?> row) {
    return Employee(
      id: _asInt(row['id']),
      employeeId: row['employee_id'] as String,
      name: row['name'] as String,
      designation: row['designation'] as String?,
      category: EmployeeCategory.fromDb(row['category'] as String? ?? 'other_staff'),
      department: row['department'] as String?,
      phone: row['contact'] as String?,
      address: row['address'] as String?,
      cnic: row['cnic'] as String?,
      joiningDate: _parseDateOrNull(row['joining_date']),
      basicSalary: _asDouble(row['basic_salary']),
      notes: row['notes'] as String?,
      status: EmployeeStatus.fromDb(row['status'] as String? ?? 'active'),
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
