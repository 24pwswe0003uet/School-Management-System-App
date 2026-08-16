// SQL query constants for Expense category reports.

/// 1. Daily Expenses — expenses for a specific date.
const String expenseDailyQuery = '''
  SELECT id, expense_id, date, category, amount, description, reference,
         created_by, created_at, updated_at
  FROM expenses
  WHERE date = ?
  ORDER BY created_at DESC
''';

/// 2. Monthly Expenses — SUM(amount) + COUNT WHERE date >= start AND date <= end.
/// This is implemented in the repository, not as a raw constant here.

/// 3. Category-wise Expenses — GROUP BY category for a date range.
const String expenseCategoryWiseQuery = '''
  SELECT category, COALESCE(SUM(amount), 0) AS total, COUNT(*) AS count
  FROM expenses
  WHERE date >= ? AND date <= ?
  GROUP BY category
  ORDER BY total DESC
''';

/// 4. Date-range Expenses — expenses between two dates.
const String expenseDateRangeQuery = '''
  SELECT id, expense_id, date, category, amount, description, reference,
         created_by, created_at, updated_at
  FROM expenses
  WHERE date BETWEEN ? AND ?
  ORDER BY date DESC
''';