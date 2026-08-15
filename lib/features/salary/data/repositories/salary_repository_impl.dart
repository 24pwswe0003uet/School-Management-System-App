import 'package:sqflite/sqflite.dart';

import '../../application/salary_calculator.dart';
import '../../domain/entities/salary_employee_pick.dart';
import '../../domain/entities/salary_monthly_totals.dart';
import '../../domain/entities/salary_period.dart';
import '../../domain/entities/salary_record.dart';
import '../../domain/entities/salary_record_list_item.dart';
import '../../domain/entities/salary_status.dart';
import '../../domain/repositories/salary_period_exists_exception.dart';
import '../../domain/repositories/salary_repository.dart';

/// SQL implementation of [SalaryRepository] over `salary_records` joined with
/// `employees`.
///
/// Integrity rules enforced here:
///   - the employee must exist (checked, and guaranteed by the FK);
///   - net amounts are always derived via [SalaryCalculator];
///   - one record per employee per month (pre-checked and enforced by the
///     UNIQUE index `(employee_id, period_start)` created in migration v10);
///   - create runs in a transaction, so a failed insert never leaves partial
///     financial data;
///   - payment date is only ever stored for Paid records.
class SalaryRepositoryImpl implements SalaryRepository {
  SalaryRepositoryImpl(this._db);

  final Database _db;

  static const String _idPrefix = 'SAL-';
  static const int _idWidth = 6;

  @override
  Future<SalaryRecord> createSalary({
    required int employeeId,
    required SalaryPeriod period,
    required double baseSalary,
    required double advance,
    required double deduction,
    required double otherAdjustment,
    required SalaryStatus status,
    DateTime? paymentDate,
    String? notes,
  }) async {
    final base = SalaryCalculator.round(baseSalary);
    final advanceValue = SalaryCalculator.round(advance);
    final deductionValue = SalaryCalculator.round(deduction);
    final adjustment = SalaryCalculator.round(otherAdjustment);
    _validateAmounts(base: base, advance: advanceValue, deduction: deductionValue);
    _requirePaymentDate(status, paymentDate);

    final employeeCode = await _employeeCode(employeeId);
    final net = SalaryCalculator.netPayable(
      base: base,
      advance: advanceValue,
      deduction: deductionValue,
      otherAdjustment: adjustment,
    );

    return _db.transaction((txn) async {
      final existing = await _queryForPeriod(txn, employeeId, period);
      if (existing != null) {
        throw SalaryPeriodExistsException(
          employeeCode: employeeCode,
          period: period,
        );
      }
      final salaryRecordId = await _nextId(txn);
      final now = _now();
      try {
        final id = await txn.insert('salary_records', {
          'salary_record_id': salaryRecordId,
          'employee_id': employeeId,
          'period_start': period.startIso,
          'period_end': period.endIso,
          'base_salary': base,
          'advance': advanceValue,
          'deduction': deductionValue,
          'other_adjustment': adjustment,
          'net_amount': net,
          'payment_date': status == SalaryStatus.paid
              ? _isoDate(paymentDate!)
              : null,
          'status': status.dbValue,
          'notes': _emptyToNull(notes),
          'created_at': now,
          'updated_at': now,
        });
        return _fromRow(
          (await txn.query(
            'salary_records',
            where: 'id = ?',
            whereArgs: [id],
          )).first,
        );
      } on DatabaseException catch (e) {
        if (_isConstraintError(e)) {
          throw SalaryPeriodExistsException(
            employeeCode: employeeCode,
            period: period,
          );
        }
        rethrow;
      }
    });
  }

  @override
  Future<SalaryRecord> updateSalary({
    required int id,
    required double baseSalary,
    required double advance,
    required double deduction,
    required double otherAdjustment,
    required SalaryStatus status,
    DateTime? paymentDate,
    String? notes,
  }) async {
    final base = SalaryCalculator.round(baseSalary);
    final advanceValue = SalaryCalculator.round(advance);
    final deductionValue = SalaryCalculator.round(deduction);
    final adjustment = SalaryCalculator.round(otherAdjustment);
    _validateAmounts(base: base, advance: advanceValue, deduction: deductionValue);
    _requirePaymentDate(status, paymentDate);

    final net = SalaryCalculator.netPayable(
      base: base,
      advance: advanceValue,
      deduction: deductionValue,
      otherAdjustment: adjustment,
    );
    await _db.update(
      'salary_records',
      {
        'base_salary': base,
        'advance': advanceValue,
        'deduction': deductionValue,
        'other_adjustment': adjustment,
        'net_amount': net,
        'payment_date': status == SalaryStatus.paid
            ? _isoDate(paymentDate!)
            : null,
        'status': status.dbValue,
        'notes': _emptyToNull(notes),
        'updated_at': _now(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return (await getSalaryRecord(id))!;
  }

  @override
  Future<SalaryRecord> markPaid({
    required int id,
    required DateTime paymentDate,
  }) async {
    await _db.update(
      'salary_records',
      {
        'status': SalaryStatus.paid.dbValue,
        'payment_date': _isoDate(paymentDate),
        'updated_at': _now(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return (await getSalaryRecord(id))!;
  }

  @override
  Future<void> deleteSalary(int id) async {
    await _db.delete('salary_records', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<SalaryRecord?> getSalaryRecord(int id) async {
    final rows = await _db.query(
      'salary_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<SalaryRecordListItem?> getSalaryRecordDetails(int id) async {
    final rows = await _db.rawQuery(
      '''
      SELECT sr.*, e.employee_id AS employee_code,
             e.name AS employee_name, e.designation AS employee_designation
      FROM salary_records sr
      JOIN employees e ON e.id = sr.employee_id
      WHERE sr.id = ?
      ''',
      [id],
    );
    if (rows.isEmpty) return null;
    return _listItemFromRow(rows.first);
  }

  @override
  Future<SalaryRecord?> getSalaryForPeriod(
    int employeeId,
    SalaryPeriod period,
  ) async {
    final rows = await _db.query(
      'salary_records',
      where: 'employee_id = ? AND period_start = ?',
      whereArgs: [employeeId, period.startIso],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<List<SalaryRecord>> salaryHistoryForEmployee(int employeeId) async {
    final rows = await _db.query(
      'salary_records',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'period_start DESC, id DESC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<SalaryRecordListItem>> searchSalaries({
    String query = '',
    SalaryPeriod? period,
    SalaryStatus? status,
    int? year,
    int? employeeId,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];

    if (employeeId != null) {
      conditions.add('sr.employee_id = ?');
      args.add(employeeId);
    }
    if (period != null) {
      conditions.add('sr.period_start = ?');
      args.add(period.startIso);
    }
    if (status != null) {
      conditions.add('sr.status = ?');
      args.add(status.dbValue);
    }
    if (year != null) {
      conditions.add("strftime('%Y', sr.period_start) = ?");
      args.add(year.toString());
    }
    final term = query.trim();
    if (term.isNotEmpty) {
      final like = '%$term%';
      conditions.add(
        '(e.employee_id LIKE ? OR e.name LIKE ?)',
      );
      args.addAll(List.filled(2, like));
    }

    final where = conditions.isEmpty ? '1 = 1' : conditions.join(' AND ');
    final rows = await _db.rawQuery(
      '''
      SELECT sr.*, e.employee_id AS employee_code,
             e.name AS employee_name, e.designation AS employee_designation
      FROM salary_records sr
      JOIN employees e ON e.id = sr.employee_id
      WHERE $where
      ORDER BY sr.period_start DESC, e.name, sr.id DESC
      LIMIT 200
      ''',
      args,
    );
    return rows.map(_listItemFromRow).toList();
  }

  @override
  Future<SalaryMonthlyTotals> monthlyTotals({
    required int year,
    required int month,
  }) async {
    final period = SalaryPeriod(year: year, month: month);
    final rows = await _db.rawQuery(
      '''
      SELECT COUNT(*) AS count,
        COALESCE(SUM(base_salary), 0) AS total_base,
        COALESCE(SUM(advance), 0) AS total_advance,
        COALESCE(SUM(deduction), 0) AS total_deduction,
        COALESCE(SUM(other_adjustment), 0) AS total_adjustment,
        COALESCE(SUM(net_amount), 0) AS net_payable,
        COALESCE(SUM(CASE WHEN status = 'paid' THEN net_amount ELSE 0 END), 0)
          AS paid,
        COALESCE(SUM(CASE WHEN status = 'pending' THEN net_amount ELSE 0 END),
          0) AS pending
      FROM salary_records
      WHERE period_start = ?
      ''',
      [period.startIso],
    );
    final row = rows.first;
    return SalaryMonthlyTotals(
      period: period,
      recordCount: _asInt(row['count']),
      totalBase: _asDouble(row['total_base']),
      totalAdvance: _asDouble(row['total_advance']),
      totalDeduction: _asDouble(row['total_deduction']),
      totalAdjustment: _asDouble(row['total_adjustment']),
      netPayable: _asDouble(row['net_payable']),
      totalPaid: _asDouble(row['paid']),
      totalPending: _asDouble(row['pending']),
    );
  }

  @override
  Future<List<SalaryEmployeePick>> searchEmployees(
    String query, {
    int limit = 20,
  }) async {
    final term = query.trim();
    if (term.isEmpty) return const [];
    final like = '%$term%';
    final rows = await _db.rawQuery(
      '''
      SELECT id, employee_id, name, designation, basic_salary
      FROM employees
      WHERE status = 'active'
        AND (employee_id LIKE ? OR name LIKE ?)
      ORDER BY name
      LIMIT ?
      ''',
      [like, like, limit],
    );
    return rows.map((r) {
      return SalaryEmployeePick(
        id: _asInt(r['id']),
        employeeCode: r['employee_id'] as String,
        name: r['name'] as String,
        designation: r['designation'] as String?,
        basicSalary: _asDouble(r['basic_salary']),
      );
    }).toList();
  }

  @override
  Future<List<int>> distinctYears() async {
    final rows = await _db.rawQuery(
      "SELECT DISTINCT CAST(strftime('%Y', period_start) AS INTEGER) AS y "
      'FROM salary_records ORDER BY y DESC',
    );
    return rows.map((r) => _asInt(r['y'])).toList();
  }

  // Helpers ----------------------------------------------------------------

  Future<Map<String, Object?>?> _queryForPeriod(
    DatabaseExecutor txn,
    int employeeId,
    SalaryPeriod period,
  ) async {
    final rows = await txn.query(
      'salary_records',
      columns: ['id'],
      where: 'employee_id = ? AND period_start = ?',
      whereArgs: [employeeId, period.startIso],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<String> _employeeCode(int employeeId) async {
    final rows = await _db.query(
      'employees',
      columns: ['employee_id'],
      where: 'id = ?',
      whereArgs: [employeeId],
    );
    if (rows.isEmpty) {
      throw ArgumentError('Employee does not exist.');
    }
    return rows.first['employee_id'] as String;
  }

  static Future<String> _nextId(DatabaseExecutor executor) async {
    final row = await executor.rawQuery(
      'SELECT COALESCE(MAX(CAST(SUBSTR(salary_record_id, ?) AS INTEGER)), 0) '
      'AS m FROM salary_records',
      [_idPrefix.length + 1],
    );
    final maxValue = (row.first['m'] as num?)?.toInt() ?? 0;
    return '$_idPrefix${(maxValue + 1).toString().padLeft(_idWidth, '0')}';
  }

  static void _validateAmounts({
    required double base,
    required double advance,
    required double deduction,
  }) {
    if (base < 0) {
      throw ArgumentError('Base salary cannot be negative.');
    }
    if (advance < 0) {
      throw ArgumentError('Advance cannot be negative.');
    }
    if (deduction < 0) {
      throw ArgumentError('Deduction cannot be negative.');
    }
  }

  static void _requirePaymentDate(SalaryStatus status, DateTime? paymentDate) {
    if (status == SalaryStatus.paid && paymentDate == null) {
      throw ArgumentError('Payment date is required when the salary is paid.');
    }
  }

  static bool _isConstraintError(DatabaseException e) {
    if (e.isUniqueConstraintError()) return true;
    final code = e.getResultCode();
    if (code == null) return false;
    return code == 19 || (code & 0xFF) == 19;
  }

  static String? _emptyToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime? _parseOptionalDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }

  static SalaryRecord _fromRow(Map<String, Object?> row) {
    return SalaryRecord(
      id: _asInt(row['id']),
      salaryRecordId: row['salary_record_id'] as String,
      employeeId: _asInt(row['employee_id']),
      period: SalaryPeriod.parse(row['period_start'] as String),
      baseSalary: _asDouble(row['base_salary']),
      advance: _asDouble(row['advance']),
      deduction: _asDouble(row['deduction']),
      otherAdjustment: _asDouble(row['other_adjustment']),
      netAmount: _asDouble(row['net_amount']),
      paymentDate: _parseOptionalDate(row['payment_date']),
      status: SalaryStatus.fromDb(row['status'] as String? ?? 'pending'),
      notes: row['notes'] as String?,
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  static SalaryRecordListItem _listItemFromRow(Map<String, Object?> row) {
    return SalaryRecordListItem(
      record: _fromRow(row),
      employeeCode: row['employee_code'] as String,
      employeeName: row['employee_name'] as String,
      designation: row['employee_designation'] as String?,
    );
  }

  static DateTime _parseDate(Object? value) {
    final parsed = DateTime.tryParse(value as String);
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static int _asInt(Object? value) => (value as num?)?.toInt() ?? 0;

  static double _asDouble(Object? value) => (value as num?)?.toDouble() ?? 0;
}
