/// One expense transaction, e.g. an electricity bill or a stationery purchase.
///
/// Amounts follow the app-wide double + round-to-2 convention and are stored
/// through SQL SUM aggregates; the entity never fabricates totals. The category
/// is free text (extendable without a migration, see migration v11); the app
/// layer always stores a non-empty value.
class Expense {
  const Expense({
    required this.id,
    required this.expenseId,
    required this.date,
    required this.category,
    required this.amount,
    required this.description,
    required this.reference,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;

  /// Human-readable code, e.g. `EXP-000001`.
  final String expenseId;

  final DateTime date;
  final String category;
  final double amount;
  final String? description;

  /// Optional vendor/bill reference number.
  final String? reference;

  /// Display name of the user who recorded the expense.
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}
