import 'expense.dart';
import 'expense_category.dart';

/// A row in the expense list: joins [Expense] with the creator's display name
/// for display purposes without loading full details.
class ExpenseListItem {
  const ExpenseListItem({
    required this.expense,
    required this.createdByName,
  });

  final Expense expense;
  final String? createdByName;

  ExpenseCategory get category => ExpenseCategory.fromDb(expense.category);
}