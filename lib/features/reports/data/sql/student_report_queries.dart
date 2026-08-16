// SQL query constants for Student category reports.

/// 1. All Students — basic list with family info.
const String studentAllQuery = '''
  SELECT s.id, s.student_id, s.name, s.gender, s.date_of_birth,
         s.admission_number, s.admission_date, s.class, s.section,
         s.contact_reference, s.notes, s.status, s.family_id,
         f.family_id AS family_id_text,
         f.guardian_name, f.mother_name, f.phone, f.alternate_phone,
         f.address, f.cnic
  FROM students s
  JOIN families f ON f.id = s.family_id
  ORDER BY s.student_id
''';

/// 2. Active Students — filter by status='active'.
const String studentActiveQuery = '''
  SELECT s.id, s.student_id, s.name, s.gender, s.date_of_birth,
         s.admission_number, s.admission_date, s.class, s.section,
         s.contact_reference, s.notes, s.status, s.family_id,
         f.family_id AS family_id_text,
         f.guardian_name, f.mother_name, f.phone, f.alternate_phone,
         f.address, f.cnic
  FROM students s
  JOIN families f ON f.id = s.family_id
  WHERE s.status = 'active'
  ORDER BY s.student_id
''';

/// 3. Students by Class — GROUP BY class with count.
const String studentByClassQuery = '''
  SELECT s.class, COUNT(*) AS student_count, GROUP_CONCAT(s.name) AS student_names
  FROM students s
  WHERE s.class IS NOT NULL AND s.class != ''
  GROUP BY s.class
  ORDER BY s.class
''';

/// 4. Students by Section — GROUP BY class, section.
const String studentBySectionQuery = '''
  SELECT s.class, s.section, COUNT(*) AS student_count, GROUP_CONCAT(s.name) AS student_names
  FROM students s
  WHERE s.class IS NOT NULL AND s.section IS NOT NULL
  GROUP BY s.class, s.section
  ORDER BY s.class, s.section
''';

/// 5. Left Students — filter by status='left'.
const String studentLeftQuery = '''
  SELECT s.id, s.student_id, s.name, s.gender, s.date_of_birth,
         s.admission_number, s.admission_date, s.class, s.section,
         s.contact_reference, s.notes, s.status, s.family_id,
         f.family_id AS family_id_text,
         f.guardian_name, f.mother_name, f.phone, f.alternate_phone,
         f.address, f.cnic
  FROM students s
  JOIN families f ON f.id = s.family_id
  WHERE s.status = 'left'
  ORDER BY s.student_id
''';

/// 6. Transferred Students — filter by status='transferred'.
const String studentTransferredQuery = '''
  SELECT s.id, s.student_id, s.name, s.gender, s.date_of_birth,
         s.admission_number, s.admission_date, s.class, s.section,
         s.contact_reference, s.notes, s.status, s.family_id,
         f.family_id AS family_id_text,
         f.guardian_name, f.mother_name, f.phone, f.alternate_phone,
         f.address, f.cnic
  FROM students s
  JOIN families f ON f.id = s.family_id
  WHERE s.status = 'transferred'
  ORDER BY s.student_id
''';

/// 7. Family-wise Students — JOIN families+students, GROUP BY family with student count.
const String studentFamilyWiseQuery = '''
  SELECT f.id, f.family_id, f.guardian_name, f.mother_name, f.phone,
         f.alternate_phone, f.address, f.cnic,
         (SELECT COUNT(*) FROM students s2 WHERE s2.family_id = f.id) AS student_count,
         GROUP_CONCAT(DISTINCT s.name) AS student_names
  FROM families f
  LEFT JOIN students s ON s.family_id = f.id
  WHERE f.status = 'active'
  GROUP BY f.id
  ORDER BY f.guardian_name
''';