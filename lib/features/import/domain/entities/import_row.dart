import 'import_fields.dart';

/// The outcome of validating and classifying one data row.
enum ImportRowVerdict {
  /// Ready to import.
  valid,

  /// Looks similar to an existing student/family but is not a definite
  /// duplicate; the operator decides whether to include it.
  possibleDuplicate,

  /// Definitely already present (admission number / student ID match);
  /// skipped automatically.
  duplicate,

  /// Failed validation; skipped with an explanation.
  invalid,
}

/// A per-field validation failure on an imported row.
class ImportRowError {
  const ImportRowError(this.field, this.message);

  final String field;
  final String message;

  @override
  String toString() => '$field: $message';
}

/// One row of an imported sheet after parsing. Core fields are keyed by
/// [ImportCoreField]; unknown columns land in [customValues] keyed by their
/// custom field name.
class ImportRow {
  ImportRow({required this.index, required this.rawValues});

  /// 0-based index within the data rows (after the header row).
  final int index;

  /// The raw cell values (plain `Object?`) aligned to the column list.
  final List<Object?> rawValues;

  final Map<ImportCoreField, Object?> coreValues = {};
  final Map<String, Object?> customValues = {};
  final List<ImportRowError> errors = [];

  ImportRowVerdict verdict = ImportRowVerdict.valid;
  String? verdictMessage;
  int? familyGroupIndex;

  String? get studentName => coreValues[ImportCoreField.studentName] as String?;

  String? get admissionNumber =>
      coreValues[ImportCoreField.admissionNumber] as String?;

  String? get existingFamilyIdValue =>
      coreValues[ImportCoreField.existingFamilyId] as String?;

  String? get studentIdValue =>
      coreValues[ImportCoreField.studentId] as String?;

  /// The guardian's name, falling back to the student's own name when the
  /// workbook has no guardian column (used for family grouping).
  String? get guardianNameForFamily =>
      coreValues[ImportCoreField.guardianName] as String? ?? studentName;

  Object? coreValue(ImportCoreField field) => coreValues[field];
}
