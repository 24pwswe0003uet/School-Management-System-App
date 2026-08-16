import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/expense/domain/entities/expense_category.dart';
import 'package:school_office_management/features/expense/domain/services/expense_service.dart';

import 'fakes/fake_expense_repository.dart';

void main() {
  group('ExpenseService', () {
    test('creates an expense via the repository', () async {
      final service = ExpenseService(FakeExpenseRepository());
      final expense = await service.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.electricity,
        amount: 5000,
        description: 'Electricity bill',
      );
      expect(expense.expenseId, startsWith('EXP-'));
      expect(service.results, isEmpty);
    });

    test('search filters by query', () async {
      final repo = FakeExpenseRepository();
      await repo.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.stationery,
        amount: 200,
        description: 'Pens and notebooks',
      );
      await repo.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.maintenance,
        amount: 500,
        description: 'Gate repair',
      );
      final service = ExpenseService(repo);

      final results = await service.searchExpenses(
        query: 'pens',
        category: null,
        dateFrom: null,
        dateTo: null,
        year: null,
        month: null,
      );
      expect(results, hasLength(1));
      expect(results.first.expense.description, contains('Pens'));
    });

    test('search filters by category', () async {
      final repo = FakeExpenseRepository();
      await repo.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.electricity,
        amount: 5000,
        description: 'Electricity',
      );
      await repo.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.water,
        amount: 500,
        description: 'Water',
      );
      final service = ExpenseService(repo);

      final results = await service.searchExpenses(
        query: '',
        category: ExpenseCategory.electricity,
        dateFrom: null,
        dateTo: null,
        year: null,
        month: null,
      );
      expect(results, hasLength(1));
    });

    test('search filters by year and month', () async {
      final repo = FakeExpenseRepository();
      await repo.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.other,
        amount: 100,
        description: 'August',
      );
      await repo.createExpense(
        date: DateTime(2026, 9, 15),
        category: ExpenseCategory.other,
        amount: 200,
        description: 'September',
      );
      final service = ExpenseService(repo);

      final results = await service.searchExpenses(
        query: '',
        category: null,
        dateFrom: null,
        dateTo: null,
        year: 2026,
        month: 8,
      );
      expect(results, hasLength(1));
      expect(results.first.expense.description, 'August');
    });

    test('deletes an expense', () async {
      final repo = FakeExpenseRepository();
      final created = await repo.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.other,
        amount: 100,
        description: 'To delete',
      );
      final service = ExpenseService(repo);

      await service.deleteExpense(created.id);
      final results = await service.searchExpenses(
        query: 'to delete',
        category: null,
        dateFrom: null,
        dateTo: null,
        year: null,
        month: null,
      );
      expect(results, isEmpty);
    });

    test('monthlyTotals returns correct totals', () async {
      final repo = FakeExpenseRepository();
      await repo.createExpense(
        date: DateTime(2026, 8, 1),
        category: ExpenseCategory.electricity,
        amount: 5000,
        description: 'Bill 1',
      );
      await repo.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.water,
        amount: 3000,
        description: 'Bill 2',
      );
      final service = ExpenseService(repo);

      final totals = await service.monthlyTotals(year: 2026, month: 8);
      expect(totals.totalAmount, 8000);
      expect(totals.recordCount, 2);
    });

    test('categoryTotals returns correct breakdown', () async {
      final repo = FakeExpenseRepository();
      await repo.createExpense(
        date: DateTime(2026, 8, 1),
        category: ExpenseCategory.electricity,
        amount: 5000,
        description: 'Electric',
      );
      await repo.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.water,
        amount: 1000,
        description: 'Water',
      );
      final service = ExpenseService(repo);

      final totals = await service.categoryTotals(
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31),
      );
      expect(totals, hasLength(2));
      final elec = totals.firstWhere((t) => t.category == ExpenseCategory.electricity);
      expect(elec.totalAmount, 5000);
    });

    test('nextExpenseId returns sequential IDs', () async {
      final repo = FakeExpenseRepository();
      final service = ExpenseService(repo);

      final id1 = await service.nextExpenseId();
      expect(id1, 'EXP-000001');

      await service.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.other,
        amount: 100,
        description: 'Test',
      );

      final id2 = await service.nextExpenseId();
      expect(id2, 'EXP-000002');
    });

    test('rejects invalid amount (<=0)', () async {
      final service = ExpenseService(FakeExpenseRepository());
      expect(
        () => service.createExpense(
          date: DateTime(2026, 8, 15),
          category: ExpenseCategory.other,
          amount: 0,
          description: 'Free',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects missing description', () async {
      final service = ExpenseService(FakeExpenseRepository());
      expect(
        () => service.createExpense(
          date: DateTime(2026, 8, 15),
          category: ExpenseCategory.other,
          amount: 100,
          description: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
