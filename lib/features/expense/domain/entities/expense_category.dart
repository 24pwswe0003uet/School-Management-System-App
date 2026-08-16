/// Expense category.
///
/// The list is deliberately extendable: the database stores the raw [dbValue]
/// string without a CHECK constraint, so new categories can be added later
/// without a migration. Unknown stored values fall back to [other] so
/// existing screens never break.
enum ExpenseCategory {
  electricity('electricity', 'Electricity'),
  water('water', 'Water'),
  stationery('stationery', 'Stationery'),
  maintenance('maintenance', 'Maintenance'),
  cleaning('cleaning', 'Cleaning'),
  furniture('furniture', 'Furniture'),
  transport('transport', 'Transport'),
  other('other', 'Other');

  const ExpenseCategory(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static ExpenseCategory fromDb(String value) {
    for (final category in ExpenseCategory.values) {
      if (category.dbValue == value) return category;
    }
    return ExpenseCategory.other;
  }
}