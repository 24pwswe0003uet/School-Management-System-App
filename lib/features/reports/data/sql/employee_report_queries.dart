// SQL query constants for Employee category reports.

/// 1. All Employees — basic list.
const String employeeAllQuery = '''
  SELECT id, employee_id, name, designation, contact, address, cnic,
         status, joining_date, basic_salary, created_at, updated_at
  FROM employees
  ORDER BY employee_id
''';

/// 2. Active Employees — filter by status='active'.
const String employeeActiveQuery = '''
  SELECT id, employee_id, name, designation, contact, address, cnic,
         status, joining_date, basic_salary, created_at, updated_at
  FROM employees
  WHERE status = 'active'
  ORDER BY employee_id
''';

/// 3. Inactive Employees — filter by status='inactive'.
const String employeeInactiveQuery = '''
  SELECT id, employee_id, name, designation, contact, address, cnic,
         status, joining_date, basic_salary, created_at, updated_at
  FROM employees
  WHERE status = 'inactive'
  ORDER BY employee_id
''';

/// 4. Employees by Category — GROUP BY category with count.
const String employeeByCategoryQuery = '''
  SELECT category, COUNT(*) AS employee_count, GROUP_CONCAT(name) AS employee_names
  FROM employees
  WHERE category IS NOT NULL AND category != ''
  GROUP BY category
  ORDER BY category
''';

/// 5. Employees by Designation — GROUP BY designation with count.
const String employeeByDesignationQuery = '''
  SELECT designation, COUNT(*) AS employee_count, GROUP_CONCAT(name) AS employee_names
  FROM employees
  WHERE designation IS NOT NULL AND designation != ''
  GROUP BY designation
  ORDER BY designation
''';