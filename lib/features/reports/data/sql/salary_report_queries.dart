// SQL query constants for Salary category reports.

// 1. Monthly Salary — reuse SalaryRepository.monthlyTotals pattern:
// COUNT(*), SUM(base_salary), SUM(advance), SUM(deduction), SUM(net_amount),
// SUM(CASE WHEN status='paid' THEN net_amount ELSE 0 END) AS paid,
// SUM(CASE WHEN status='pending' THEN net_amount ELSE 0 END) AS pending.
// This is implemented in the repository, not as a raw constant here.

/// 2. Paid Salary — SUM(net_amount) WHERE status='paid' AND period_start month.
const String salaryPaidQuery = '''
  SELECT COALESCE(SUM(net_amount), 0) AS total_paid
  FROM salary_records
  WHERE status = 'paid' AND strftime('%Y-%m', period_start) = ?
''';

/// 3. Pending Salary — SUM(net_amount) WHERE status='pending' AND period_start month.
const String salaryPendingQuery = '''
  SELECT COALESCE(SUM(net_amount), 0) AS total_pending
  FROM salary_records
  WHERE status = 'pending' AND strftime('%Y-%m', period_start) = ?
''';

/// 4. Advances — SUM(advance) WHERE period_start month.
const String salaryAdvancesQuery = '''
  SELECT COALESCE(SUM(advance), 0) AS total_advances
  FROM salary_records
  WHERE strftime('%Y-%m', period_start) = ?
''';

/// 5. Deductions — SUM(deduction) WHERE period_start month.
const String salaryDeductionsQuery = '''
  SELECT COALESCE(SUM(deduction), 0) AS total_deductions
  FROM salary_records
  WHERE strftime('%Y-%m', period_start) = ?
''';

/// 6. Employee Salary History — full history for a specific employee.
const String salaryEmployeeHistoryQuery = '''
  SELECT sr.*, e.employee_id AS employee_code, e.name AS employee_name,
         e.designation AS employee_designation, e.category,
         e.basic_salary, e.advance, e.deduction, e.net_amount,
         sr.period_start, sr.period_end, sr.payment_date, sr.status
  FROM salary_records sr
  JOIN employees e ON e.id = sr.employee_id
  WHERE sr.employee_id = ?
  ORDER BY sr.period_start DESC
''';