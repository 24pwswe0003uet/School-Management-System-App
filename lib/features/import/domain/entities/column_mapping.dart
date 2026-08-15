import 'custom_field.dart';
import 'import_fields.dart';

/// How a workbook column was matched to a target.
enum ColumnMatchStatus {
  /// Recognized exactly by the alias table or an existing custom field.
  autoMatched,

  /// Recognized with lower confidence (substring/proximity); shown for
  /// confirmation.
  suggested,

  /// No target matched; the column becomes a custom field unless ignored.
  unknown,

  /// The user chose to skip this column entirely.
  ignored,
}

/// What a workbook column maps to.
enum ColumnTargetKind { core, custom, ignored }

/// The plan for one workbook column: which header it came from and what it
/// maps to. Mappings are never applied silently — every target carries an
/// explicit [status] shown in the mapping UI.
class ColumnMapping {
  ColumnMapping({
    required this.index,
    required this.sourceHeader,
    required this.normalizedHeader,
    required this.kind,
    required this.status,
    this.coreField,
    this.customFieldName,
    this.customDisplayName,
    this.customEntityType,
    this.customDataType,
  });

  /// 0-based column index in the sheet.
  final int index;

  /// The header exactly as written in the workbook.
  final String sourceHeader;

  /// Normalized form used for matching.
  final String normalizedHeader;

  ColumnTargetKind kind;
  ColumnMatchStatus status;
  ImportCoreField? coreField;
  String? customFieldName;
  String? customDisplayName;
  String? customEntityType;
  CustomFieldDataType? customDataType;

  bool get isIgnored => kind == ColumnTargetKind.ignored;
  bool get isCore => kind == ColumnTargetKind.core;
  bool get isCustom => kind == ColumnTargetKind.custom;

  /// Label shown in the mapping table.
  String get targetLabel {
    switch (kind) {
      case ColumnTargetKind.ignored:
        return 'Ignore column';
      case ColumnTargetKind.core:
        return coreField?.displayName ?? sourceHeader;
      case ColumnTargetKind.custom:
        return customDisplayName ?? customFieldName ?? sourceHeader;
    }
  }

  ColumnMapping asCore(ImportCoreField field, ColumnMatchStatus match) {
    return ColumnMapping(
      index: index,
      sourceHeader: sourceHeader,
      normalizedHeader: normalizedHeader,
      kind: ColumnTargetKind.core,
      status: match,
      coreField: field,
    );
  }

  ColumnMapping asCustom(
    String fieldName,
    String displayName, {
    String entityType = 'student',
    CustomFieldDataType? dataType,
    ColumnMatchStatus match = ColumnMatchStatus.unknown,
  }) {
    return ColumnMapping(
      index: index,
      sourceHeader: sourceHeader,
      normalizedHeader: normalizedHeader,
      kind: ColumnTargetKind.custom,
      status: match,
      customFieldName: fieldName,
      customDisplayName: displayName,
      customEntityType: entityType,
      customDataType: dataType,
    );
  }

  ColumnMapping asIgnored() {
    return ColumnMapping(
      index: index,
      sourceHeader: sourceHeader,
      normalizedHeader: normalizedHeader,
      kind: ColumnTargetKind.ignored,
      status: ColumnMatchStatus.ignored,
    );
  }
}
