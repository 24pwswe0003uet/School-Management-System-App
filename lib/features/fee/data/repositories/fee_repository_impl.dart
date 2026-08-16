import 'package:sqflite/sqflite.dart';

import '../../domain/entities/family_outstanding_row.dart';
import '../../domain/entities/fee_generation_result.dart';
import '../../domain/entities/fee_period.dart';
import '../../domain/entities/fee_record.dart';
import '../../domain/entities/fee_record_details.dart';
import '../../domain/entities/fee_record_list_item.dart';
import '../../domain/entities/fee_status.dart';
import '../../domain/entities/fee_structure.dart';
import '../../domain/entities/fee_student_pick.dart';
import '../../domain/entities/monthly_collection_report.dart';
import '../../domain/entities/payment_record.dart';
import '../../domain/entities/receipt_data.dart';
import '../../domain/entities/unpaid_student_row.dart';
import '../../domain/repositories/fee_repository.dart';

/// SQL implementation of [FeeRepository].
///
/// Data-integrity rules enforced here (each inside one transaction):
///   - a payment insert updates the record's paid/remaining/status atomically;
///   - a reversal flags the payment and restores the balance atomically;
///   - overpayment is rejected;
///   - receipt numbers are unique;
///   - generation is idempotent (unique `(student_id, period_start)`).
class FeeRepositoryImpl implements FeeRepository {
  FeeRepositoryImpl(this._db);

  final Database _db;

  static const String _idPrefixPayments = 'PAY-';
  static const String _idPrefixReceipts = 'RCP-';
  static const String _idPrefixStructures = 'FS-';
  static const int _idWidth = 6;

  @override
  Future<List<FeeStructure>> listFeeStructures() async {
    final rows = await _db.query(
      'fee_structures',
      orderBy:
          "CASE WHEN fee_type = 'admission' THEN 0 WHEN class_name IS NULL THEN 1 ELSE 2 END, "
          'COALESCE(class_name, \'\')',
    );
    return rows.map(_structureFromRow).toList();
  }

  @override
  Future<FeeStructure> createFeeStructure({
    required String name,
    String? className,
    required double monthlyAmount,
    double discountAmount = 0,
    String? description,
    required FeeType feeType,
  }) async {
    _validateStructure(name, monthlyAmount, discountAmount);

    // Validate className exists in academic_classes when provided.
    if (className != null && className.isNotEmpty) {
      final classRows = await _db.query(
        'academic_classes',
        where: 'class_name = ?',
        whereArgs: [className],
      );
      if (classRows.isEmpty) {
        throw ArgumentError(
            'Invalid class name. Configure the class in Settings → Academic → Classes first.');
      }
    }

    final structureId = await _nextId(
      _db,
      'fee_structures',
      'structure_id',
      _idPrefixStructures,
    );
    final now = _now();
    try {
      final id = await _db.insert('fee_structures', {
        'structure_id': structureId,
        'name': name.trim(),
        'class_name': _emptyToNull(className),
        'monthly_amount': monthlyAmount,
        'discount_amount': discountAmount,
        'description': _emptyToNull(description),
        'fee_type': feeType.dbValue,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      return (await _getStructure(id))!;
    } on DatabaseException catch (e) {
      if (_isConstraintError(e)) {
        final typeLabel = feeType.label;
        final classLabel = className ?? 'default (no class)';
        throw ArgumentError('A $typeLabel fee rule already exists for $classLabel.');
      }
      rethrow;
    }
  }

  @override
  Future<FeeStructure> updateFeeStructure({
    required int id,
    required String name,
    String? className,
    required double monthlyAmount,
    double discountAmount = 0,
    String? description,
    required FeeType feeType,
  }) async {
    _validateStructure(name, monthlyAmount, discountAmount);

    // Validate className exists in academic_classes when provided.
    if (className != null && className.isNotEmpty) {
      final classRows = await _db.query(
        'academic_classes',
        where: 'class_name = ?',
        whereArgs: [className],
      );
      if (classRows.isEmpty) {
        throw ArgumentError(
            'Invalid class name. Configure the class in Settings → Academic → Classes first.');
      }
    }

    try {
      await _db.update(
        'fee_structures',
        {
          'name': name.trim(),
          'class_name': _emptyToNull(className),
          'monthly_amount': monthlyAmount,
          'discount_amount': discountAmount,
          'description': _emptyToNull(description),
          'fee_type': feeType.dbValue,
          'updated_at': _now(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
      if (_isConstraintError(e)) {
        final typeLabel = feeType.label;
        final classLabel = className ?? 'default (no class)';
        throw ArgumentError('A $typeLabel fee rule already exists for $classLabel.');
      }
      rethrow;
    }
    return (await _getStructure(id))!;
  }

  @override
  Future<void> setFeeStructureActive(int id, bool isActive) async {
    await _db.update(
      'fee_structures',
      {'is_active': isActive ? 1 : 0, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<FeeStructure?> _getStructure(int id) async {
    final rows = await _db.query(
      'fee_structures',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _structureFromRow(rows.first);
  }

  @override
  Future<FeeGenerationResult> generateMonthlyFees({
    required int year,
    required int month,
    void Function(int processed, int total)? onProgress,
  }) async {
    final period = FeePeriod(year: year, month: month);
    final rules = await _loadActiveRules();
    final students = await _db.query(
      'students',
      columns: ['id', 'class'],
      where: "status = 'active'",
    );

    var created = 0;
    var alreadyExists = 0;
    var noRule = 0;
    final total = students.length;

    await _db.transaction((txn) async {
      for (var i = 0; i < students.length; i++) {
        final row = students[i];
        final idValue = row['id'];
        if (idValue == null) {
          print('Warning: student row missing id at index $i');
          noRule++;
          onProgress?.call(i + 1, total);
          continue;
        }
        final studentId = (idValue as num?)?.toInt() ?? 0;
        if (studentId == 0) {
          print('Warning: invalid student id at index $i: $idValue');
          noRule++;
          onProgress?.call(i + 1, total);
          continue;
        }
        final studentClass = row['class'] as String?;
        // Only pick monthly fee rules; skip admission rules.
        final rule = rules.resolveForMonthly(studentClass);
        if (rule == null) {
          noRule++;
        } else {
          final expected = rule.monthlyAmount;
          final discount = rule.discountAmount;
          final net = _netPayable(expected, discount, 0);
          final now = _now();
          try {
            final feeRecordId = await _nextId(
              txn,
              'fee_records',
              'fee_record_id',
              'FEE-',
            );
            await txn.insert('fee_records', {
              'fee_record_id': feeRecordId,
              'student_id': studentId,
              'period_start': period.startIso,
              'period_end': period.endIso,
              'expected_amount': expected,
              'discount': discount,
              'fine': 0,
              'net_payable': net,
              'paid_amount': 0,
              'remaining_amount': net,
              'status': 'pending',
              'created_at': now,
              'updated_at': now,
            });
            created++;
          } on DatabaseException catch (e) {
            if (_isConstraintError(e)) {
              alreadyExists++;
            } else {
              rethrow;
            }
          }
        }
        onProgress?.call(i + 1, total);
      }
    });

    return FeeGenerationResult(
      created: created,
      alreadyExists: alreadyExists,
      noRule: noRule,
    );
  }

  Future<_ActiveRules> _loadActiveRules() async {
    final rows = await _db.query(
      'fee_structures',
      where: 'is_active = 1',
    );
    return _ActiveRules(rows.map(_structureFromRow).toList());
  }

  @override
  Future<List<FeeRecordListItem>> searchFeeRecords({
    String query = '',
    FeePeriod? period,
    FeeStatus? status,
    String? className,
    int? studentId,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];

    if (studentId != null) {
      conditions.add('fr.student_id = ?');
      args.add(studentId);
    }
    if (period != null) {
      conditions.add('fr.period_start = ?');
      args.add(period.startIso);
    }
    if (status != null) {
      conditions.add('fr.status = ?');
      args.add(status.dbValue);
    }
    if (className != null && className.isNotEmpty) {
      conditions.add('s.class = ?');
      args.add(className);
    }
    final term = query.trim();
    if (term.isNotEmpty) {
      final like = '%$term%';
      conditions.add(
        '(s.student_id LIKE ? OR s.name LIKE ? '
        "OR COALESCE(f.guardian_name, '') LIKE ? "
        "OR COALESCE(s.admission_number, '') LIKE ?)",
      );
      args.addAll(List.filled(4, like));
    }

    final where = conditions.isEmpty ? '1 = 1' : conditions.join(' AND ');
    final rows = await _db.rawQuery(
      '''
      SELECT fr.*,
             s.student_id AS student_code,
             s.name AS student_name,
             s.class AS student_class,
             s.section AS student_section,
             f.guardian_name
      FROM fee_records fr
      JOIN students s ON s.id = fr.student_id
      LEFT JOIN families f ON f.id = s.family_id
      WHERE $where
      ORDER BY fr.period_start DESC, s.name, fr.id DESC
      LIMIT 200
      ''',
      args,
    );
    return rows.map((r) {
      return FeeRecordListItem(
        record: _recordFromRow(r),
        studentId: r['student_code'] as String,
        studentName: r['student_name'] as String,
        guardianName: r['guardian_name'] as String?,
        className: r['student_class'] as String?,
        section: r['student_section'] as String?,
      );
    }).toList();
  }

  @override
  Future<FeeRecord?> getFeeRecord(int id) async {
    final rows = await _db.query(
      'fee_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _recordFromRow(rows.first);
  }

  @override
  Future<FeeRecordDetails> getFeeRecordDetails(int id) async {
    final rows = await _db.rawQuery(
      '''
      SELECT fr.*,
             s.student_id AS student_code,
             s.name AS student_name,
             s.class AS student_class,
             s.section AS student_section,
             f.guardian_name
      FROM fee_records fr
      JOIN students s ON s.id = fr.student_id
      LEFT JOIN families f ON f.id = s.family_id
      WHERE fr.id = ?
      ''',
      [id],
    );
    if (rows.isEmpty) {
      throw ArgumentError('Fee record $id does not exist.');
    }
    final row = rows.first;
    final paymentRows = await _db.rawQuery(
      'SELECT * FROM payments WHERE fee_record_id = ? '
      'ORDER BY payment_date DESC, id DESC',
      [id],
    );
    return FeeRecordDetails(
      record: _recordFromRow(row),
      studentId: row['student_code'] as String,
      studentName: row['student_name'] as String,
      guardianName: row['guardian_name'] as String?,
      className: row['student_class'] as String?,
      section: row['student_section'] as String?,
      payments: paymentRows.map(_paymentFromRow).toList(),
    );
  }

  @override
  Future<List<FeeRecord>> listOpenFeeRecords(int studentId) async {
    final rows = await _db.query(
      'fee_records',
      where: "student_id = ? AND status IN ('pending', 'partial')",
      whereArgs: [studentId],
      orderBy: 'period_start ASC',
    );
    return rows.map(_recordFromRow).toList();
  }

  @override
  Future<FeeRecord?> getFeeRecordForPeriod(
    int studentId,
    FeePeriod period,
  ) async {
    final rows = await _db.query(
      'fee_records',
      where: 'student_id = ? AND period_start = ?',
      whereArgs: [studentId, period.startIso],
    );
    return rows.isEmpty ? null : _recordFromRow(rows.first);
  }

  @override
  Future<List<FeeRecord>> studentFeeHistory(int studentId) async {
    final rows = await _db.query(
      'fee_records',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'period_start DESC, id DESC',
    );
    return rows.map(_recordFromRow).toList();
  }

  @override
  Future<List<FeeStudentPick>> searchStudents(
    String query, {
    int limit = 20,
  }) async {
    final term = query.trim();
    if (term.isEmpty) return const [];
    final like = '%$term%';
    final rows = await _db.rawQuery(
      '''
      SELECT s.id, s.student_id, s.name, s.class, s.section,
             f.guardian_name
      FROM students s
      LEFT JOIN families f ON f.id = s.family_id
      WHERE s.status = 'active'
        AND (s.student_id LIKE ? OR s.name LIKE ?
             OR COALESCE(f.guardian_name, '') LIKE ?
             OR COALESCE(s.admission_number, '') LIKE ?)
      ORDER BY s.name
      LIMIT ?
      ''',
      [like, like, like, like, limit],
    );
    return rows.map((r) {
      return FeeStudentPick(
        id: (r['id'] as num).toInt(),
        studentId: r['student_id'] as String,
        name: r['name'] as String,
        className: r['class'] as String?,
        section: r['section'] as String?,
        guardianName: r['guardian_name'] as String?,
      );
    }).toList();
  }

  @override
  Future<List<String>> distinctClasses() async {
    final rows = await _db.rawQuery(
      "SELECT DISTINCT class_name FROM academic_classes WHERE is_active = 1 ORDER BY class_name",
    );
    return rows.map((r) => r['class_name'] as String).toList();
  }

  @override
  Future<PaymentRecord> recordPayment({
    required int feeRecordId,
    required int studentId,
    required double amount,
    required DateTime paymentDate,
    String? receiptNumber,
    String? note,
    int? createdByUserId,
    String? createdByName,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'fee_records',
        where: 'id = ?',
        whereArgs: [feeRecordId],
      );
      if (rows.isEmpty) {
        throw ArgumentError('Fee record $feeRecordId does not exist.');
      }
      final row = rows.first;
      if ((row['student_id'] as num).toInt() != studentId) {
        throw ArgumentError('Payment student does not match the fee record.');
      }
      final netPayable = _asDouble(row['net_payable']);
      final paid = _asDouble(row['paid_amount']);
      final remaining = _remaining(netPayable, paid);
      if (amount > remaining + 0.0001) {
        throw OverpaymentException(remaining);
      }

      final receipt = await _resolveReceipt(txn, receiptNumber);
      final paymentId = await _nextId(
        txn,
        'payments',
        'payment_id',
        _idPrefixPayments,
      );
      final now = _now();
      final id = await txn.insert('payments', {
        'payment_id': paymentId,
        'student_id': studentId,
        'fee_record_id': feeRecordId,
        'amount': amount,
        'payment_date': _isoDate(paymentDate),
        'receipt_number': receipt,
        'note': _emptyToNull(note),
        'created_by': createdByUserId,
        'created_by_name': _emptyToNull(createdByName),
        'status': 'active',
        'created_at': now,
      });

      final newPaid = paid + amount;
      final newRemaining = _remaining(netPayable, newPaid);
      final newStatus = newRemaining <= 0.0001 ? 'paid' : 'partial';
      await txn.update(
        'fee_records',
        {
          'paid_amount': newPaid,
          'remaining_amount': newRemaining,
          'status': newStatus,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [feeRecordId],
      );

      return _paymentFromRow((await txn.query(
        'payments',
        where: 'id = ?',
        whereArgs: [id],
      )).first);
    });
  }

  /// Returns the receipt to use: the operator's value when supplied (checked
  /// for uniqueness), otherwise the next auto-generated number.
  Future<String> _resolveReceipt(
    DatabaseExecutor txn,
    String? receiptNumber,
  ) async {
    if (receiptNumber == null || receiptNumber.trim().isEmpty) {
      return _nextId(txn, 'payments', 'receipt_number', _idPrefixReceipts);
    }
    final value = receiptNumber.trim();
    final existing = await txn.query(
      'payments',
      columns: ['id'],
      where: 'receipt_number = ? COLLATE NOCASE',
      whereArgs: [value],
    );
    if (existing.isNotEmpty) {
      throw DuplicateReceiptException(value);
    }
    return value;
  }

  @override
  Future<PaymentRecord> reversePayment({
    required int paymentId,
    int? byUserId,
    String? byName,
    String? reason,
  }) async {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'payments',
        where: 'id = ?',
        whereArgs: [paymentId],
      );
      if (rows.isEmpty) {
        throw ArgumentError('Payment $paymentId does not exist.');
      }
      final paymentRow = rows.first;
      if (paymentRow['status'] == 'reversed') {
        throw ArgumentError('Payment $paymentId is already reversed.');
      }
      final feeRecordId = (paymentRow['fee_record_id'] as num).toInt();
      final amount = _asDouble(paymentRow['amount']);
      final now = _now();
      await txn.update(
        'payments',
        {
          'status': 'reversed',
          'reversed_at': now,
          'reversed_by': byUserId,
          'reversed_by_name': _emptyToNull(byName),
          'reverse_reason': _emptyToNull(reason),
        },
        where: 'id = ?',
        whereArgs: [paymentId],
      );

      final feeRows = await txn.query(
        'fee_records',
        where: 'id = ?',
        whereArgs: [feeRecordId],
      );
      final feeRow = feeRows.first;
      final netPayable = _asDouble(feeRow['net_payable']);
      final paid = _asDouble(feeRow['paid_amount']);
      final newPaid = (paid - amount).clamp(0, netPayable).toDouble();
      final newRemaining = _remaining(netPayable, newPaid);
      final newStatus = newRemaining <= 0.0001
          ? (newPaid <= 0.0001 ? 'pending' : 'paid')
          : (newPaid <= 0.0001 ? 'pending' : 'partial');
      await txn.update(
        'fee_records',
        {
          'paid_amount': newPaid,
          'remaining_amount': newRemaining,
          'status': newStatus,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [feeRecordId],
      );

      return _paymentFromRow((await txn.query(
        'payments',
        where: 'id = ?',
        whereArgs: [paymentId],
      )).first);
    });
  }

  @override
  Future<FeeRecord> adjustFeeRecord({
    required int feeRecordId,
    double? discount,
    double? fine,
  }) async {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'fee_records',
        where: 'id = ?',
        whereArgs: [feeRecordId],
      );
      if (rows.isEmpty) {
        throw ArgumentError('Fee record $feeRecordId does not exist.');
      }
      final row = rows.first;
      final expected = _asDouble(row['expected_amount']);
      final nextDiscount = discount ?? _asDouble(row['discount']);
      final nextFine = fine ?? _asDouble(row['fine']);
      if (nextDiscount < 0 || nextFine < 0) {
        throw ArgumentError('Discount and fine cannot be negative.');
      }
      final net = _netPayable(expected, nextDiscount, nextFine);
      final paid = _asDouble(row['paid_amount']);
      final remaining = _remaining(net, paid);
      final status = remaining <= 0.0001
          ? (paid <= 0.0001 ? 'pending' : 'paid')
          : (paid <= 0.0001 ? 'pending' : 'partial');
      await txn.update(
        'fee_records',
        {
          'discount': nextDiscount,
          'fine': nextFine,
          'net_payable': net,
          'remaining_amount': remaining,
          'status': status,
          'updated_at': _now(),
        },
        where: 'id = ?',
        whereArgs: [feeRecordId],
      );
      return _recordFromRow((await txn.query(
        'fee_records',
        where: 'id = ?',
        whereArgs: [feeRecordId],
      )).first);
    });
  }

  @override
  Future<String> nextReceiptNumber() {
    return _nextId(_db, 'payments', 'receipt_number', _idPrefixReceipts);
  }

  @override
  Future<ReceiptData?> receiptData(int paymentId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT p.payment_id, p.amount, p.payment_date, p.receipt_number,
             p.note, p.created_by_name, p.status,
             s.student_id, s.name AS student_name, f.guardian_name,
             fr.period_start, fr.period_end, fr.expected_amount,
             fr.discount, fr.fine, fr.net_payable, fr.paid_amount,
             fr.remaining_amount
      FROM payments p
      JOIN fee_records fr ON fr.id = p.fee_record_id
      JOIN students s ON s.id = p.student_id
      LEFT JOIN families f ON f.id = s.family_id
      WHERE p.id = ?
      ''',
      [paymentId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    final period = FeePeriod.parse(r['period_start'] as String);
    return ReceiptData(
      paymentId: r['payment_id'] as String,
      receiptNumber: (r['receipt_number'] as String?) ?? '',
      studentId: r['student_id'] as String,
      studentName: r['student_name'] as String,
      guardianName: r['guardian_name'] as String?,
      periodLabel: period.label,
      expectedAmount: _asDouble(r['expected_amount']),
      discount: _asDouble(r['discount']),
      fine: _asDouble(r['fine']),
      netPayable: _asDouble(r['net_payable']),
      paidAmount: _asDouble(r['paid_amount']),
      remainingAmount: _asDouble(r['remaining_amount']),
      paymentDate: _parseDate(r['payment_date']),
      paymentNote: r['note'] as String?,
      createdByName: r['created_by_name'] as String?,
      isReversed: r['status'] == 'reversed',
    );
  }

  @override
  Future<MonthlyCollectionReport> monthlyCollection({
    required int year,
    required int month,
  }) async {
    final period = FeePeriod(year: year, month: month);
    final rows = await _db.rawQuery(
      '''
      SELECT COUNT(*) AS count, COALESCE(SUM(amount), 0) AS total
      FROM payments
      WHERE status = 'active' AND strftime('%Y-%m', payment_date) = ?
      ''',
      [period.monthKey],
    );
    final row = rows.first;
    return MonthlyCollectionReport(
      period: period,
      collected: _asDouble(row['total']),
      paymentCount: _asInt(row['count']),
    );
  }

  @override
  Future<double> totalOutstanding() async {
    final rows = await _db.rawQuery(
      "SELECT COALESCE(SUM(remaining_amount), 0) AS total "
      "FROM fee_records WHERE status IN ('pending', 'partial')",
    );
    return _asDouble(rows.first['total']);
  }

  @override
  Future<List<UnpaidStudentRow>> unpaidStudents(FeePeriod period) async {
    final rows = await _db.rawQuery(
      '''
      SELECT fr.*,
             s.student_id AS student_code,
             s.name AS student_name,
             s.class AS student_class,
             s.section AS student_section,
             f.guardian_name
      FROM fee_records fr
      JOIN students s ON s.id = fr.student_id
      LEFT JOIN families f ON f.id = s.family_id
      WHERE fr.period_start = ?
        AND fr.status IN ('pending', 'partial')
      ORDER BY s.name
      ''',
      [period.startIso],
    );
    return rows.map((r) {
      return UnpaidStudentRow(
        record: _recordFromRow(r),
        studentId: r['student_code'] as String,
        studentName: r['student_name'] as String,
        className: r['student_class'] as String?,
        section: r['student_section'] as String?,
        guardianName: r['guardian_name'] as String?,
      );
    }).toList();
  }

  @override
  Future<List<FamilyOutstandingRow>> familyOutstanding() async {
    final rows = await _db.rawQuery(
      '''
      SELECT f.id, f.family_id, f.guardian_name,
             COUNT(DISTINCT s.id) AS student_count,
             COALESCE(SUM(CASE WHEN fr.id IS NOT NULL
                               THEN fr.remaining_amount ELSE 0 END), 0)
               AS outstanding
      FROM families f
      LEFT JOIN students s ON s.family_id = f.id
      LEFT JOIN fee_records fr
        ON fr.student_id = s.id
       AND fr.status IN ('pending', 'partial')
      WHERE f.status = 'active'
      GROUP BY f.id
      HAVING outstanding > 0.0001
      ORDER BY outstanding DESC
      ''',
    );
    return rows.map((r) {
      return FamilyOutstandingRow(
        familyId: (r['id'] as num).toInt(),
        familyCode: r['family_id'] as String,
        guardianName: r['guardian_name'] as String,
        studentCount: _asInt(r['student_count']),
        outstanding: _asDouble(r['outstanding']),
      );
    }).toList();
  }

  // Helpers ----------------------------------------------------------------

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
    final maxValue = (row.first['m'] as num?)?.toInt() ?? 0;
    return '$prefix${(maxValue + 1).toString().padLeft(_idWidth, '0')}';
  }

  static void _validateStructure(
    String name,
    double monthlyAmount,
    double discountAmount,
  ) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Rule name is required.');
    }
    if (monthlyAmount < 0 || discountAmount < 0) {
      throw ArgumentError('Amounts cannot be negative.');
    }
  }

  /// `expected - discount + fine`, clamped at zero.
  static double _netPayable(double expected, double discount, double fine) {
    final value = expected - discount + fine;
    return value < 0 ? 0 : value;
  }

  static double _remaining(double netPayable, double paid) {
    final value = netPayable - paid;
    return value < 0 ? 0 : value;
  }

  static bool _isConstraintError(DatabaseException e) {
    if (e.isUniqueConstraintError() || e.isNotNullConstraintError()) {
      return true;
    }
    final code = e.getResultCode();
    if (code == null) return false;
    // SQLITE_CONSTRAINT = 19. Extended codes keep the primary code in the low
    // byte (e.g. 0x0313 = SQLITE_CONSTRAINT_FOREIGNKEY), so mask it off.
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

  static DateTime _parseDate(Object? value) {
    final parsed = DateTime.tryParse(value as String);
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static int _asInt(Object? value) => (value as num?)?.toInt() ?? 0;

  static double _asDouble(Object? value) => (value as num?)?.toDouble() ?? 0;

  static FeeStructure _structureFromRow(Map<String, Object?> row) {
    return FeeStructure(
      id: _asInt(row['id']),
      structureId: row['structure_id'] as String,
      name: row['name'] as String,
      className: row['class_name'] as String?,
      monthlyAmount: _asDouble(row['monthly_amount']),
      discountAmount: _asDouble(row['discount_amount']),
      feeType: _feeTypeFromDb(row['fee_type'] as String?),
      description: row['description'] as String?,
      isActive: (row['is_active'] as num?)?.toInt() == 1,
    );
  }

  static FeeType _feeTypeFromDb(String? dbValue) {
    if (dbValue == null) return FeeType.monthly;
    switch (dbValue.trim().toLowerCase()) {
      case 'admission':
        return FeeType.admission;
      case 'monthly':
      default:
        return FeeType.monthly;
    }
  }

  static FeeRecord _recordFromRow(Map<String, Object?> row) {
    return FeeRecord(
      id: _asInt(row['id']),
      feeRecordId: row['fee_record_id'] as String,
      studentId: _asInt(row['student_id']),
      period: FeePeriod.parse(row['period_start'] as String),
      expectedAmount: _asDouble(row['expected_amount']),
      discount: _asDouble(row['discount']),
      fine: _asDouble(row['fine']),
      netPayable: _asDouble(row['net_payable']),
      paidAmount: _asDouble(row['paid_amount']),
      remainingAmount: _asDouble(row['remaining_amount']),
      status: FeeStatus.fromDb(row['status'] as String? ?? 'pending'),
    );
  }

  static PaymentRecord _paymentFromRow(Map<String, Object?> row) {
    return PaymentRecord(
      id: _asInt(row['id']),
      paymentId: row['payment_id'] as String,
      studentId: _asInt(row['student_id']),
      feeRecordId: _asInt(row['fee_record_id']),
      amount: _asDouble(row['amount']),
      paymentDate: _parseDate(row['payment_date']),
      receiptNumber: row['receipt_number'] as String?,
      note: row['note'] as String?,
      createdByUserId: (row['created_by'] as num?)?.toInt(),
      createdByName: row['created_by_name'] as String?,
      status: PaymentStatus.fromDb(row['status'] as String? ?? 'active'),
      reversedAt: _parseOptionalDate(row['reversed_at']),
      reversedByName: row['reversed_by_name'] as String?,
      reverseReason: row['reverse_reason'] as String?,
    );
  }

  static DateTime? _parseOptionalDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }
}

/// The active fee rules, resolved by class with a global default fallback.
class _ActiveRules {
  _ActiveRules(List<FeeStructure> structures)
      : _byClassAdmission = {
          for (final s in structures)
            if (s.className != null && s.feeType == FeeType.admission) s.className!: s,
        },
        _byClassMonthly = {
          for (final s in structures)
            if (s.className != null && s.feeType == FeeType.monthly) s.className!: s,
        },
        _defaultMonthly =
            structures.where((s) => s.feeType == FeeType.monthly && s.isDefault).firstOrNull,
        _defaultAdmission =
            structures.where((s) => s.feeType == FeeType.admission && s.isDefault).firstOrNull;

  final Map<String, FeeStructure> _byClassMonthly;
  final Map<String, FeeStructure> _byClassAdmission;
  final FeeStructure? _defaultMonthly;
  final FeeStructure? _defaultAdmission;

  /// Returns the monthly fee rule for [className], or the default monthly rule.
  FeeStructure? resolveForMonthly(String? className) {
    if (className != null && _byClassMonthly.containsKey(className)) {
      return _byClassMonthly[className];
    }
    return _defaultMonthly;
  }

  /// Returns the admission fee rule for [className], or the default admission rule.
  FeeStructure? resolveForAdmission(String? className) {
    if (className != null && _byClassAdmission.containsKey(className)) {
      return _byClassAdmission[className];
    }
    return _defaultAdmission;
  }
}
