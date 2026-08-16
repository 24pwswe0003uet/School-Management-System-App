// SQL query constants for the Financial Summary report.

// Financial Summary for a selected date range:
// - Fee Income Charged: SUM(fee_records.net_payable) WHERE period within range
// - Fee Income Collected: SUM(payments.amount) WHERE status='active' AND date within range
// - Salary Expenses: SUM(salary_records.net_amount) WHERE status IN ('paid','pending') AND period within range
// - Other Expenses: SUM(expenses.amount) WHERE date within range
// - Net Position = Fee Income Charged - Fee Income Collected - Salary Expenses - Other Expenses

/// Fee Income Charged (net_payable from fee_records within date range).
const String financialFeeIncomeChargedQuery = '''
  SELECT COALESCE(SUM(fr.net_payable), 0) AS total
  FROM fee_records fr
  WHERE fr.period_start >= ? AND fr.period_end <= ?
''';

/// Fee Income Collected (actual payments amount within date range).
const String financialFeeIncomeCollectedQuery = '''
  SELECT COALESCE(SUM(p.amount), 0) AS total
  FROM payments p
  WHERE p.status = 'active' AND date(p.payment_date) BETWEEN ? AND ?
''';

/// Salary Expenses (paid + pending net_amount within date range).
const String financialSalaryExpensesQuery = '''
  SELECT COALESCE(SUM(sr.net_amount), 0) AS total
  FROM salary_records sr
  WHERE sr.period_start >= ? AND sr.period_end <= ?
  AND sr.status IN ('paid', 'pending')
''';

/// Other Expenses (expenses amount within date range).
const String financialOtherExpensesQuery = '''
  SELECT COALESCE(SUM(e.amount), 0) AS total
  FROM expenses e
  WHERE e.date BETWEEN ? AND ?
''';