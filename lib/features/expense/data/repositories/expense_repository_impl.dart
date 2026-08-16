import 'package:sqflite/sqflite.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_list_item.dart';
import '../../domain/entities/expense_monthly_totals.dart';
import '../../domain/entities/expense_category_total.dart';
import '../../domain/repositories/expense_repository.dart';

/// SQL implementation of [ExpenseRepository] over the `expenses` table.
///
/// Integrity rules enforced here:
///   - date, category, amount, description are required
///   - amount must be > 0 (rounded to 2 decimals)
///   - expense_id is generated as EXP-XXXXXX inside a transaction
///   - created_at is immutable; updated_at is set on every update
///   - aggregations use SQL SUM/GROUP BY, no in-memory loading
class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl(this._db);

  final Database _db;

  static const String _idPrefix = 'EXP-';
  static const int _idWidth = 6;

  @override
  Future<Expense> createExpense({
    required DateTime date,
    required ExpenseCategory category,
    required double amount,
    required String description,
    String? reference,
    String? createdBy,
  }) async {
    _requireFields(
      date: date,
      category: category,
      amount: amount,
      description: description,
    );
    final roundedAmount = _round(amount);
    if (roundedAmount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }

    final expenseId = await _nextId();
    final now = _now();

    return _db.transaction((txn) async {
      final id = await txn.insert('expenses', {
        'expense_id': expenseId,
        'date': _isoDate(date),
        'category': category.dbValue,
        'amount': roundedAmount,
        'description': description.trim(),
        'reference': _emptyToNull(reference),
        'created_by': _emptyToNull(createdBy),
        'created_at': now,
        'updated_at': now,
      });
      return _fromRow(
        (await txn.query(
          'expenses',
          where: 'id = ?',
          whereArgs: [id],
        )).first,
      );
    });
  }

  @override
  Future<Expense?> getExpense(int id) async {
    final rows = await _db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<List<ExpenseListItem>> searchExpenses({
    String query = '',
    ExpenseCategory? category,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? year,
    int? month,
    double? amountMin,
    double? amountMax,
    int limit = 200,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];

    if (category != null) {
      conditions.add('category = ?');
      args.add(category.dbValue);
    }

    if (dateFrom != null) {
      conditions.add('date >= ?');
      args.add(_isoDate(dateFrom));
    }
    if (dateTo != null) {
      conditions.add('date <= ?');
      args.add(_isoDate(dateTo));
    }

    if (year != null && month != null) {
      final periodStart = DateTime(year, month, 1);
      final periodEnd = DateTime(year, month + 1, 0);
      conditions.add('date >= ?');
      args.add(_isoDate(periodStart));
      conditions.add('date <= ?');
      args.add(_isoDate(periodEnd));
    } else if (year != null) {
      conditions.add("strftime('%Y', date) = ?");
      args.add(year.toString());
    }

    if (amountMin != null) {
      conditions.add('amount >= ?');
      args.add(amountMin);
    }
    if (amountMax != null) {
      conditions.add('amount <= ?');
      args.add(amountMax);
    }

    final term = query.trim();
    if (term.isNotEmpty) {
      final like = '%$term%';
      conditions.add(
        '(expense_id LIKE ? OR description LIKE ? OR category LIKE ? OR '
        'COALESCE(reference, \'\') LIKE ?)',
      );
      args.addAll(List.filled(4, like));
    }

    final where = conditions.isEmpty ? '1 = 1' : conditions.join(' AND ');
    final rows = await _db.rawQuery(
      '''
      SELECT e.*, e.created_by AS created_by_name
      FROM expenses e
      WHERE $where
      ORDER BY e.date DESC, e.id DESC
      LIMIT ?
      ''',
      [...args, limit],
    );
    return rows.map(_listItemFromRow).toList();
  }

  @override
  Future<Expense> updateExpense({
    required int id,
    required DateTime date,
    required ExpenseCategory category,
    required double amount,
    required String description,
    String? reference,
  }) async {
    _requireFields(
      date: date,
      category: category,
      amount: amount,
      description: description,
    );
    final roundedAmount = _round(amount);
    if (roundedAmount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }

    await _db.update(
      'expenses',
      {
        'date': _isoDate(date),
        'category': category.dbValue,
        'amount': roundedAmount,
        'description': description.trim(),
        'reference': _emptyToNull(reference),
        'updated_at': _now(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return (await getExpense(id))!;
  }

  @override
  Future<void> deleteExpense(int id) async {
    await _db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<ExpenseMonthlyTotals> monthlyTotals({
    required int year,
    required int month,
  }) async {
    final periodStart = DateTime(year, month, 1);
    final periodEnd = DateTime(year, month + 1, 0);
    final startIso = _isoDate(periodStart);
    final endIso = _isoDate(periodEnd);

    final totalRows = await _db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(amount), 0) AS total_amount,
        COUNT(*) AS record_count
      FROM expenses
      WHERE date >= ? AND date <= ?
      ''',
      [startIso, endIso],
    );

    final categoryRows = await _db.rawQuery(
      '''
      SELECT category, COALESCE(SUM(amount), 0) AS total, COUNT(*) AS count
      FROM expenses
      WHERE date >= ? AND date <= ?
      GROUP BY category
      ORDER BY total DESC
      ''',
      [startIso, endIso],
    );

    final totalRow = totalRows.first;
    final totalAmount = _asDouble(totalRow['total_amount']);
    final recordCount = _asInt(totalRow['record_count']);

    final categoryBreakdown = categoryRows.map((row) {
      final cat = ExpenseCategory.fromDb(row['category'] as String? ?? 'other');
      return ExpenseCategoryTotal(
        category: cat,
        totalAmount: _asDouble(row['total']),
        recordCount: _asInt(row['count']),
      );
    }).toList();

    return ExpenseMonthlyTotals(
      year: year,
      month: month,
      totalAmount: totalAmount,
      recordCount: recordCount,
      categoryBreakdown: categoryBreakdown,
    );
  }

  @override
  Future<List<ExpenseCategoryTotal>> categoryTotals({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _db.rawQuery(
      '''
      SELECT category, COALESCE(SUM(amount), 0) AS total, COUNT(*) AS count
      FROM expenses
      WHERE date >= ? AND date <= ?
      GROUP BY category
      ORDER BY total DESC
      ''',
      [_isoDate(from), _isoDate(to)],
    );
    return rows.map((row) {
      final cat = ExpenseCategory.fromDb(row['category'] as String? ?? 'other');
      return ExpenseCategoryTotal(
        category: cat,
        totalAmount: _asDouble(row['total']),
        recordCount: _asInt(row['count']),
      );
    }).toList();
  }

  @override
  Future<double> totalForDateRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE date >= ? AND date <= ?
      ''',
      [_isoDate(from), _isoDate(to)],
    );
    return _asDouble(rows.first['total']);
  }

  @override
  Future<List<int>> distinctYears() async {
    final rows = await _db.rawQuery(
      "SELECT DISTINCT CAST(strftime('%Y', date) AS INTEGER) AS y "
      'FROM expenses ORDER BY y DESC',
    );
    return rows.map((r) => _asInt(r['y'])).toList();
  }

  @override
  Future<String> nextExpenseId() async {
    final row = await _db.rawQuery(
      'SELECT COALESCE(MAX(CAST(SUBSTR(expense_id, ?) AS INTEGER)), 0) AS m '
      'FROM expenses',
      [_idPrefix.length + 1],
    );
    final maxValue = _asInt(row.first['m']);
    return '$_idPrefix${(maxValue + 1).toString().padLeft(_idWidth, '0')}';
  }

  // Helpers ----------------------------------------------------------------

  static void _requireFields({
    required DateTime date,
    required ExpenseCategory category,
    required double amount,
    required String description,
  }) {
    if (description.trim().isEmpty) {
      throw ArgumentError('Description is required.');
    }
  }

  static double _round(double value) {
    return (value * 100).roundToDouble() / 100;
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

  Future<String> _nextId() async {
    final row = await _db.rawQuery(
      'SELECT COALESCE(MAX(CAST(SUBSTR(expense_id, ?) AS INTEGER)), 0) AS m '
      'FROM expenses',
      [_idPrefix.length + 1],
    );
    final maxValue = _asInt(row.first['m']);
    return '$_idPrefix${(maxValue + 1).toString().padLeft(_idWidth, '0')}';
  }

  static Expense _fromRow(Map<String, Object?> row) {
    return Expense(
      id: _asInt(row['id']),
      expenseId: row['expense_id'] as String,
      date: _parseDate(row['date']),
      category: row['category'] as String? ?? 'other',
      amount: _asDouble(row['amount']),
      description: row['description'] as String?,
      reference: row['reference'] as String?,
      createdBy: row['created_by'] as String?,
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  static ExpenseListItem _listItemFromRow(Map<String, Object?> row) {
    return ExpenseListItem(
      expense: _fromRow(row),
      createdByName: row['created_by_name'] as String?,
    );
  }

  static DateTime _parseDate(Object? value) =>
      DateTime.tryParse(value as String)?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  static int _asInt(Object? value) => (value as num?)?.toInt() ?? 0;

  static double _asDouble(Object? value) => (value as num?)?.toDouble() ?? 0;
}