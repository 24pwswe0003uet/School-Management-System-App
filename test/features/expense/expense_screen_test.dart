import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_office_management/features/expense/domain/entities/expense_category.dart';
import 'package:school_office_management/features/expense/domain/services/expense_service.dart';
import 'package:school_office_management/features/expense/presentation/expense_form_screen.dart';
import 'package:school_office_management/features/expense/presentation/expense_list_screen.dart';
import 'package:school_office_management/features/expense/presentation/expense_screen.dart';

import 'fakes/fake_expense_repository.dart';

void main() {
  group('ExpenseScreen', () {
    testWidgets('shows three menu tiles', (tester) async {
      final service = ExpenseService(FakeExpenseRepository());
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseScreen(expenseService: service),
        ),
      );

      expect(find.text('Expense List'), findsOneWidget);
      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
    });
  });

  group('ExpenseFormScreen', () {
    testWidgets('validates required description field', (tester) async {
      final service = ExpenseService(FakeExpenseRepository());
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseFormScreen(expenseService: service),
        ),
      );

      await tester.tap(find.byKey(const Key('expense_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a description.'), findsOneWidget);
      expect(find.text('Amount is required.'), findsOneWidget);
    });

    testWidgets('validates amount greater than zero', (tester) async {
      final service = ExpenseService(FakeExpenseRepository());
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseFormScreen(expenseService: service),
        ),
      );

      await tester.enterText(find.byKey(const Key('expense_description')), 'Office supplies');
      await tester.enterText(find.byKey(const Key('expense_amount')), '0');
      await tester.tap(find.byKey(const Key('expense_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Amount must be greater than zero.'), findsOneWidget);
    });

    testWidgets('validates amount is a valid number', (tester) async {
      final service = ExpenseService(FakeExpenseRepository());
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseFormScreen(expenseService: service),
        ),
      );

      await tester.enterText(find.byKey(const Key('expense_description')), 'Office supplies');
      await tester.enterText(find.byKey(const Key('expense_amount')), 'not-a-number');
      await tester.tap(find.byKey(const Key('expense_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid amount.'), findsOneWidget);
    });

    testWidgets('creates an expense when form is valid', (tester) async {
      final repo = FakeExpenseRepository();
      final service = ExpenseService(repo);
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseFormScreen(expenseService: service),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('expense_description')),
        'Monthly electricity bill',
      );
      await tester.enterText(
        find.byKey(const Key('expense_amount')),
        '5000',
      );
      await tester.tap(find.byKey(const Key('expense_submit')));
      await tester.pumpAndSettle();

      expect(repo.all, hasLength(1));
      expect(repo.all.first.description, 'Monthly electricity bill');
      expect(repo.all.first.amount, 5000);
    });

    testWidgets('prefills fields when editing', (tester) async {
      final repo = FakeExpenseRepository();
      final service = ExpenseService(repo);
      final expense = await repo.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.electricity,
        amount: 5000,
        description: 'Original bill',
        reference: 'REF-001',
        createdBy: 'Admin',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseFormScreen(expenseService: service, existing: expense),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Edit Expense'), findsOneWidget);
      expect(
        find.textContaining('Original bill'),
        findsWidgets,
      );
    });
  });

  group('ExpenseListScreen', () {
    testWidgets('shows empty state when no expenses', (tester) async {
      final service = ExpenseService(FakeExpenseRepository());
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseListScreen(expenseService: service),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No expenses match these filters.'), findsOneWidget);
    });

    testWidgets('displays expenses after search', (tester) async {
      final repo = FakeExpenseRepository();
      await repo.createExpense(
        date: DateTime(2026, 8, 15),
        category: ExpenseCategory.electricity,
        amount: 5000,
        description: 'Electricity bill',
        createdBy: 'Admin',
      );
      final service = ExpenseService(repo);
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseListScreen(expenseService: service),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('EXP-000001'), findsOneWidget);
      expect(find.textContaining('Electricity bill'), findsOneWidget);
    });
  });
}
