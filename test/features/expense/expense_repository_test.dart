import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/core/database/app_database.dart';
import 'package:school_office_management/features/expense/data/repositories/expense_repository_impl.dart';
import 'package:school_office_management/features/expense/domain/entities/expense_category.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppDatabase? database;
  late ExpenseRepositoryImpl repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await database?.close();
    database = null;
  });

  Future<void> openDb() async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    database = db;
    repository = ExpenseRepositoryImpl(db.raw);
  }

  group('ExpenseRepositoryImpl createExpense', () {
    test('creates and persists a new expense with EXP-XXXXXX id', () async {
      await openDb();
      final expense = await repository.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.electricity,
        amount: 5000,
        description: 'Monthly electricity bill',
        reference: 'BILL-2026-08',
      );

      expect(expense.id, greaterThan(0));
      expect(expense.expenseId, startsWith('EXP-'));
      expect(expense.category, 'electricity');
      expect(expense.amount, 5000);
      expect(expense.description, 'Monthly electricity bill');
      expect(expense.reference, 'BILL-2026-08');

      final loaded = await repository.getExpense(expense.id);
      expect(loaded, isNotNull);
      expect(loaded!.expenseId, expense.expenseId);
    });

    test('auto-increments the expense ID sequence', () async {
      await openDb();
      final first = await repository.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.other,
        amount: 100,
        description: 'First expense',
      );
      final second = await repository.createExpense(
        date: DateTime(2026, 8, 16),
        category: ExpenseCategory.other,
        amount: 200,
        description: 'Second expense',
      );

      expect(first.expenseId, 'EXP-000001');
      expect(second.expenseId, 'EXP-000002');
    });

    test('rejects amount <= 0', () async {
      await openDb();
      expect(
        () => repository.createExpense(
          date: DateTime(2026, 8, 15),
          category: ExpenseCategory.other,
          amount: 0,
          description: 'Free item',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('requires a non-empty description', () async {
      await openDb();
      expect(
        () => repository.createExpense(
          date: DateTime(2026, 8, 15),
          category: ExpenseCategory.other,
          amount: 100,
          description: '  ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rounds amount to 2 decimals', () async {
      await openDb();
      final expense = await repository.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.other,
        amount: 100.999,
        description: 'Rounding test',
      );
      expect(expense.amount, 101.0);
    });
  });

  group('ExpenseRepositoryImpl updateExpense', () {
    test('updates an existing expense and sets updated_at', () async {
      await openDb();
      final created = await repository.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.electricity,
        amount: 5000,
        description: 'Electricity bill',
      );

      await Future.delayed(const Duration(milliseconds: 10));
      final updated = await repository.updateExpense(
        id: created.id,
        date: DateTime(2026, 9, 1),
        category: ExpenseCategory.water,
        amount: 6000,
        description: 'Updated water bill',
        reference: 'REF-002',
      );

      expect(updated.category, 'water');
      expect(updated.amount, 6000);
      expect(updated.description, 'Updated water bill');
      expect(updated.reference, 'REF-002');

      final loaded = await repository.getExpense(created.id);
      expect(loaded!.category, 'water');
    });
  });

  group('ExpenseRepositoryImpl searchExpenses', () {
    test('returns matching results by description text', () async {
      await openDb();
      await repository.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.stationery,
        amount: 200,
        description: 'Pens and notebooks',
      );
      await repository.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.maintenance,
        amount: 500,
        description: 'Gate repair',
      );

      final results = await repository.searchExpenses(query: 'pens');
      expect(results, hasLength(1));
      expect(results.first.expense.description, contains('Pens'));
    });

    test('filters by category', () async {
      await openDb();
      await repository.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.electricity,
        amount: 5000,
        description: 'Electricity',
      );
      await repository.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.water,
        amount: 500,
        description: 'Water',
      );

      final results = await repository.searchExpenses(
        category: ExpenseCategory.electricity,
      );
      expect(results, hasLength(1));
      expect(results.first.category, ExpenseCategory.electricity);
    });

    test('filters by year and month', () async {
      await openDb();
      await repository.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.other,
        amount: 100,
        description: 'Aug expense',
      );
      await repository.createExpense(
        date: DateTime(2026, 9, 15),
        category: ExpenseCategory.other,
        amount: 200,
        description: 'Sep expense',
      );

      final results = await repository.searchExpenses(year: 2026, month: 8);
      expect(results, hasLength(1));
      expect(results.first.expense.description, 'Aug expense');
    });

    test('filters by date range', () async {
      await openDb();
      await repository.createExpense(
        date: DateTime(2026, 8, 10),
        category: ExpenseCategory.other,
        amount: 100,
        description: 'Early Aug',
      );
      await repository.createExpense(
        date: DateTime(2026, 8, 20),
        category: ExpenseCategory.other,
        amount: 200,
        description: 'Late Aug',
      );
      await repository.createExpense(
        date: DateTime(2026, 9, 1),
        category: ExpenseCategory.other,
        amount: 300,
        description: 'September',
      );

      final results = await repository.searchExpenses(
        dateFrom: DateTime(2026, 8, 1),
        dateTo: DateTime(2026, 8, 31),
      );
      expect(results, hasLength(2));
    });

    test('returns empty list when no matches', () async {
      await openDb();
      await repository.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.other,
        amount: 100,
        description: 'Office supplies',
      );

      final results = await repository.searchExpenses(query: 'nonexistent');
      expect(results, isEmpty);
    });
  });

  group('ExpenseRepositoryImpl monthlyTotals', () {
    test('sums amounts and counts records for a month', () async {
      await openDb();
      await repository.createExpense(
        date: DateTime(2026, 8, 1),
        category: ExpenseCategory.electricity,
        amount: 5000,
        description: 'Bill 1',
      );
      await repository.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.water,
        amount: 3000,
        description: 'Bill 2',
      );
      await repository.createExpense(
        date: DateTime(2026, 9, 1),
        category: ExpenseCategory.other,
        amount: 2000,
        description: 'Sep',
      );

      final totals = await repository.monthlyTotals(year: 2026, month: 8);
      expect(totals.totalAmount, 8000);
      expect(totals.recordCount, 2);
      expect(totals.categoryBreakdown, hasLength(2));
    });
  });

  group('ExpenseRepositoryImpl categoryTotals', () {
    test('returns category breakdown for a date range', () async {
      await openDb();
      await repository.createExpense(
        date: DateTime(2026, 8, 1),
        category: ExpenseCategory.electricity,
        amount: 5000,
        description: 'Electric',
      );
      await repository.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.electricity,
        amount: 2000,
        description: 'Electric 2',
      );
      await repository.createExpense(
        date: DateTime(2026, 8, 20),
        category: ExpenseCategory.water,
        amount: 1000,
        description: 'Water',
      );

      final totals = await repository.categoryTotals(
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31),
      );
      expect(totals, hasLength(2));
      final elec = totals.firstWhere((t) => t.category == ExpenseCategory.electricity);
      expect(elec.totalAmount, 7000);
      expect(elec.recordCount, 2);
    });
  });

  group('ExpenseRepositoryImpl deleteExpense', () {
    test('permanently removes an expense', () async {
      await openDb();
      final expense = await repository.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.other,
        amount: 100,
        description: 'To delete',
      );

      await repository.deleteExpense(expense.id);

      expect(await repository.getExpense(expense.id), isNull);
    });
  });

  group('ExpenseRepositoryImpl nextExpenseId', () {
    test('returns EXP-000001 for empty table', () async {
      await openDb();
      final id = await repository.nextExpenseId();
      expect(id, 'EXP-000001');
    });

    test('returns next sequential ID after inserts', () async {
      await openDb();
      await repository.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.other,
        amount: 100,
        description: 'First',
      );
      final id = await repository.nextExpenseId();
      expect(id, 'EXP-000002');
    });
  });

  group('ExpenseRepositoryImpl distinctYears', () {
    test('returns distinct years descending', () async {
      await openDb();
      await repository.createExpense(
        date: DateTime(2025, 1, 15),
        category: ExpenseCategory.other,
        amount: 100,
        description: '2025',
      );
      await repository.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.other,
        amount: 200,
        description: '2026',
      );
      await repository.createExpense(
        date: DateTime(2026, 6, 15),
        category: ExpenseCategory.other,
        amount: 300,
        description: '2026 again',
      );

      final years = await repository.distinctYears();
      expect(years, [2026, 2025]);
    });
  });
}
