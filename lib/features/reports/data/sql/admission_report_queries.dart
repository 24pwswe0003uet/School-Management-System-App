// SQL query constants for Admission category reports.

/// 1. Admissions by Date — admissions within a date range.
const String admissionByDateQuery = '''
  SELECT a.id, a.admission_id, a.admission_date, a.class, a.section,
         a.admission_number, a.admission_fee,
         s.student_id, s.name AS student_name, s.gender,
         f.guardian_name, f.mother_name, f.phone
  FROM admissions a
  JOIN students s ON s.id = a.student_id
  LEFT JOIN families f ON f.id = s.family_id
  WHERE a.admission_date BETWEEN ? AND ?
  ORDER BY a.admission_date DESC
''';

/// 2. Admissions by Month — GROUP BY month-year.
const String admissionByMonthQuery = '''
  SELECT strftime('%Y-%m', a.admission_date) AS month_year,
         COUNT(*) AS admission_count,
         GROUP_CONCAT(DISTINCT s.name) AS student_names
  FROM admissions a
  JOIN students s ON s.id = a.student_id
  GROUP BY month_year
  ORDER BY month_year DESC
''';

/// 3. Admissions by Year — GROUP BY year.
const String admissionByYearQuery = '''
  SELECT strftime('%Y', a.admission_date) AS admission_year,
         COUNT(*) AS admission_count,
         GROUP_CONCAT(DISTINCT s.name) AS student_names
  FROM admissions a
  JOIN students s ON s.id = a.student_id
  GROUP BY admission_year
  ORDER BY admission_year DESC
''';

/// 4. Admissions by Class — JOIN students, GROUP BY class.
const String admissionByClassQuery = '''
  SELECT s.class, COUNT(*) AS admission_count,
         GROUP_CONCAT(DISTINCT a.admission_id) AS admission_ids,
         GROUP_CONCAT(DISTINCT s.name) AS student_names
  FROM admissions a
  JOIN students s ON s.id = a.student_id
  GROUP BY s.class
  ORDER BY s.class
''';