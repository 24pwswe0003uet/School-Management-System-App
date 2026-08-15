import 'column_mapping.dart';
import 'import_family_group.dart';
import 'import_row.dart';

/// The complete, validated plan for importing one sheet. Built after mapping,
/// validation and classification; shown to the operator before anything is
/// written.
class ImportPlan {
  ImportPlan({
    required this.sheetName,
    required this.columns,
    required this.rows,
    required this.familyGroups,
  });

  final String sheetName;
  final List<ColumnMapping> columns;
  final List<ImportRow> rows;
  final List<ImportFamilyGroup> familyGroups;

  int get totalRows => rows.length;
  int get validCount =>
      rows.where((r) => r.verdict == ImportRowVerdict.valid).length;
  int get possibleDuplicateCount =>
      rows.where((r) => r.verdict == ImportRowVerdict.possibleDuplicate).length;
  int get duplicateCount =>
      rows.where((r) => r.verdict == ImportRowVerdict.duplicate).length;
  int get invalidCount =>
      rows.where((r) => r.verdict == ImportRowVerdict.invalid).length;

  int get customFieldCount =>
      columns.where((c) => c.kind == ColumnTargetKind.custom).length;

  int get familiesNeeded =>
      familyGroups.where((g) => g.match == ImportFamilyMatch.none).length;

  bool get hasIssues =>
      duplicateCount > 0 || possibleDuplicateCount > 0 || invalidCount > 0;
}
