// SQL query constants for Fee category reports.

/// 1. Daily Collection — payments for a specific date.
const String feeDailyCollectionQuery = '''
  SELECT p.payment_id, p.amount, p.payment_date, p.receipt_number, p.note,
         s.student_id, s.name AS student_name, s.class AS student_class,
         f.guardian_name
  FROM payments p
  JOIN students s ON s.id = p.student_id
  LEFT JOIN families f ON f.id = s.family_id
  WHERE date(p.payment_date) = ?
  ORDER BY p.payment_date DESC
''';

/// 2. Monthly Collection — COUNT + SUM(amount) where status='active' and month match.
const String feeMonthlyCollectionQuery = '''
  SELECT COUNT(*) AS count,
         COALESCE(SUM(p.amount), 0) AS total
  FROM payments p
  WHERE p.status = 'active' AND strftime('%Y-%m', p.payment_date) = ?
''';

/// 3. Outstanding Fees — SUM(remaining_amount) where status IN ('pending','partial').
const String feeOutstandingQuery = '''
  SELECT COALESCE(SUM(fr.remaining_amount), 0) AS total_outstanding
  FROM fee_records fr
  WHERE fr.status IN ('pending', 'partial')
''';

/// 4. Paid Students — students with paid fee records in a period.
const String feePaidStudentsQuery = '''
  SELECT s.id, s.student_id, s.name, s.class, s.section,
         fr.period_start, fr.period_end, fr.expected_amount,
         fr.paid_amount, fr.remaining_amount, fr.status
  FROM fee_records fr
  JOIN students s ON s.id = fr.student_id
  WHERE fr.status = 'paid' AND strftime('%Y-%m', fr.period_start) = ?
  ORDER BY s.name
''';

/// 5. Unpaid Students — students with unpaid/partial fee records in a period.
const String feeUnpaidStudentsQuery = '''
  SELECT s.id, s.student_id, s.name, s.class, s.section,
         fr.period_start, fr.period_end, fr.expected_amount,
         fr.remaining_amount, fr.status
  FROM fee_records fr
  JOIN students s ON s.id = fr.student_id
  WHERE fr.status IN ('pending', 'partial') AND strftime('%Y-%m', fr.period_start) = ?
  ORDER BY s.name
''';

/// 6. Partial Payments — fee records with status='partial' in a period.
const String feePartialPaymentsQuery = '''
  SELECT s.id, s.student_id, s.name, s.class, s.section,
         fr.period_start, fr.period_end, fr.expected_amount,
         fr.paid_amount, fr.remaining_amount, fr.status
  FROM fee_records fr
  JOIN students s ON s.id = fr.student_id
  WHERE fr.status = 'partial' AND strftime('%Y-%m', fr.period_start) = ?
  ORDER BY s.name
''';

/// 7. Student Fee History — full history for a specific student.
const String feeStudentHistoryQuery = '''
  SELECT fr.*, s.student_id AS student_code, s.name AS student_name,
         s.class AS student_class, s.section AS student_section,
         f.guardian_name
  FROM fee_records fr
  JOIN students s ON s.id = fr.student_id
  LEFT JOIN families f ON f.id = s.family_id
  WHERE s.id = ?
  ORDER BY fr.period_start DESC
''';

/// 8. Family Fee Summary — aggregated outstanding balance per family.
const String feeFamilySummaryQuery = '''
  SELECT f.id, f.family_id, f.guardian_name,
         COUNT(DISTINCT s.id) AS student_count,
         COALESCE(SUM(CASE WHEN fr.status IN ('pending', 'partial') THEN fr.remaining_amount ELSE 0 END), 0) AS outstanding
  FROM families f
  LEFT JOIN students s ON s.family_id = f.id
  LEFT JOIN fee_records fr ON fr.student_id = s.id AND fr.status IN ('pending', 'partial')
  WHERE f.status = 'active'
  GROUP BY f.id
  HAVING outstanding > 0.0001
  ORDER BY outstanding DESC
''';