import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../../family/domain/entities/family.dart';
import '../../family/domain/services/family_service.dart';
import '../../settings/domain/services/settings_service.dart';
import '../../student/domain/entities/student.dart';
import '../../student/domain/services/student_service.dart';
import '../../student/presentation/student_details_screen.dart';
import 'admission_wizard_screen.dart';

/// Shown after a successful admission. Offers to open the new student's
/// profile, start another admission, or return to the dashboard. Printing an
/// admission receipt is not implemented yet, so no print action is offered.
class AdmissionSuccessScreen extends StatelessWidget {
  const AdmissionSuccessScreen({
    super.key,
    required this.studentService,
    required this.familyService,
    required this.settingsService,
    required this.student,
    required this.family,
    required this.admissionNumber,
    required this.admissionFee,
  });

  final StudentService studentService;
  final FamilyService familyService;
  final SettingsService settingsService;
  final Student student;
  final Family family;
  final String admissionNumber;
  final double admissionFee;

  Future<void> _openStudent(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentDetailsScreen(
          studentService: studentService,
          familyService: familyService,
          settingsService: settingsService,
          studentId: student.id,
        ),
      ),
    );
  }

  void _newAdmission(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdmissionWizardScreen(
          studentService: studentService,
          familyService: familyService,
          settingsService: settingsService,
        ),
      ),
    );
  }

  void _returnToDashboard(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Admission Complete')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Admission saved',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${student.name} has been admitted successfully.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _summaryRow(theme, 'Student', student.name),
                    _summaryRow(theme, 'Student ID', student.studentId),
                    _summaryRow(theme, 'Family', family.familyId),
                    _summaryRow(theme, 'Family guardian', family.guardianName),
                    _summaryRow(
                      theme,
                      'Admission number',
                      admissionNumber.isEmpty ? '—' : admissionNumber,
                    ),
                    _summaryRow(
                      theme,
                      'Admission fee',
                      admissionFee > 0 ? Formatters.money(admissionFee) : '—',
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('adm_success_open_student'),
                        onPressed: () => _openStudent(context),
                        icon: const Icon(Icons.school_rounded),
                        label: const Text('Open Student'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const Key('adm_success_new_admission'),
                        onPressed: () => _newAdmission(context),
                        icon: const Icon(Icons.how_to_reg_rounded),
                        label: const Text('New Admission'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('adm_success_dashboard'),
                      onPressed: () => _returnToDashboard(context),
                      child: const Text('Return to Dashboard'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
