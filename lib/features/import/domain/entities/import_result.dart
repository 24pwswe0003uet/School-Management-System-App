import 'import_row.dart';

/// The outcome of actually importing a plan.
class ImportResult {
  ImportResult({
    required this.importedFamilies,
    required this.importedStudents,
    required this.skippedDuplicates,
    required this.skippedInvalid,
    required this.createdCustomFields,
    required this.failures,
  });

  final int importedFamilies;
  final int importedStudents;
  final int skippedDuplicates;
  final int skippedInvalid;
  final List<String> createdCustomFields;
  final List<ImportRowError> failures;

  bool get succeeded => failures.isEmpty;

  int get totalProcessed =>
      importedFamilies + importedStudents + skippedDuplicates + skippedInvalid;
}
