/// Enumerates the available report categories in the Reports module.
///
/// Each category maps to a group of related reports with shared filter
/// requirements and aggregation strategies.
enum ReportCategory {
  student('Student', 'Student reports'),
  admission('Admission', 'Admission reports'),
  fee('Fee', 'Fee reports'),
  employee('Employee', 'Employee reports'),
  salary('Salary', 'Salary reports'),
  expense('Expense', 'Expense reports'),
  financial('Financial', 'Financial summary');

  const ReportCategory(this.displayName, this.description);

  final String displayName;
  final String description;
}

extension ReportCategoryExtension on ReportCategory {
  String get iconPath => switch (this) {
    ReportCategory.student => 'assets/icons/student.png',
    ReportCategory.admission => 'assets/icons/admission.png',
    ReportCategory.fee => 'assets/icons/fee.png',
    ReportCategory.employee => 'assets/icons/employee.png',
    ReportCategory.salary => 'assets/icons/salary.png',
    ReportCategory.expense => 'assets/icons/expense.png',
    ReportCategory.financial => 'assets/icons/financial.png',
  };
}