import '../entities/column_mapping.dart';
import '../entities/custom_field.dart';
import '../entities/import_fields.dart';

/// Matches workbook column headers to import targets using an extensible
/// alias table. Every match is tiered: exact alias hits are auto-applied,
/// weaker matches are flagged as suggestions for the operator, and anything
/// unrecognized becomes a custom field — a workbook is never rejected for an
/// unknown column.
class ColumnMapper {
  /// Canonical field -> known header spellings. Add new aliases here.
  static const Map<ImportCoreField, List<String>> aliases = {
    ImportCoreField.studentName: [
      'Student Name',
      'Student',
      'Student Full Name',
      'Name',
      'Full Name',
      'Pupil Name',
      "Pupil's Name",
    ],
    ImportCoreField.gender: ['Gender', 'Sex'],
    ImportCoreField.dateOfBirth: [
      'Date of Birth',
      'DOB',
      'Birth Date',
      'Birthdate',
      'Date of Birthday',
    ],
    ImportCoreField.admissionNumber: [
      'Admission Number',
      'Admission No',
      'Admission No.',
      'Admission',
      'Admission#',
      'Roll No',
      'Roll Number',
      'Roll',
      'Roll#',
    ],
    ImportCoreField.admissionDate: [
      'Admission Date',
      'Date of Admission',
      'Joining Date',
      'Enrollment Date',
      'Enrolment Date',
    ],
    ImportCoreField.className: [
      'Class',
      'Grade',
      'Grade Level',
      'Form',
      'Standard',
      'Class Name',
    ],
    ImportCoreField.section: ['Section'],
    ImportCoreField.admissionFee: [
      'Admission Fee',
      'Admission Fees',
      'Registration Fee',
      'Fee',
    ],
    ImportCoreField.contactReference: [
      'Contact Reference',
      'Reference',
      'Contact Person',
    ],
    ImportCoreField.notes: ['Notes', 'Remarks', 'Comments', 'Note'],
    ImportCoreField.guardianName: [
      "Father's Name",
      'Father Name',
      'Father',
      'Guardian Name',
      'Guardian',
      'Parent Name',
      'Parent',
      'Father/Guardian',
      'Parent/Guardian',
      'Fathers Name',
    ],
    ImportCoreField.motherName: [
      "Mother's Name",
      'Mother Name',
      'Mother',
      'Mothers Name',
    ],
    ImportCoreField.primaryPhone: [
      'Phone',
      'Phone Number',
      'Primary Phone',
      'Mobile',
      'Mobile Number',
      'Contact Number',
      'Contact',
      'Cell',
      'Cell Number',
      'Guardian Phone',
      'Father Phone',
      'Guardian Contact',
    ],
    ImportCoreField.secondaryPhone: [
      'Alternate Phone',
      'Secondary Phone',
      'Other Phone',
      'Alternate Contact',
      'Alternate Number',
    ],
    ImportCoreField.address: [
      'Address',
      'Home Address',
      'Residential Address',
      'Permanent Address',
      'Address Line',
    ],
    ImportCoreField.cnic: [
      'CNIC',
      'NIC',
      'National ID',
      'National Identity',
      'National ID Card',
      'B-Form',
      'B Form',
      'Form B',
      'CNIC Number',
    ],
    ImportCoreField.existingFamilyId: [
      'Family ID',
      'Family',
      'Family Code',
      'Existing Family',
      'Existing Family ID',
    ],
    ImportCoreField.studentId: ['Student ID', 'Student Id No', 'ID'],
  };

  /// Canonical field -> normalized alias set (built once).
  static final Map<ImportCoreField, Set<String>> _normalizedAliases =
      _buildNormalizedAliases();

  static Map<ImportCoreField, Set<String>> _buildNormalizedAliases() {
    final result = <ImportCoreField, Set<String>>{};
    for (final entry in aliases.entries) {
      result[entry.key] = entry.value.map(normalizeHeader).toSet();
    }
    return result;
  }

  static String normalizeHeader(String header) {
    return header
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Builds the mapping for a list of headers.
  List<ColumnMapping> mapColumns(
    List<String> headers, {
    required List<CustomFieldDefinition> customFields,
  }) {
    final usedSlugs = <String>{};
    final results = <ColumnMapping>[];
    for (var i = 0; i < headers.length; i++) {
      final header = headers[i];
      final normalized = normalizeHeader(header);
      if (normalized.isEmpty) {
        results.add(
          ColumnMapping(
            index: i,
            sourceHeader: header,
            normalizedHeader: normalized,
            kind: ColumnTargetKind.ignored,
            status: ColumnMatchStatus.ignored,
          ),
        );
        continue;
      }

      final core = _exactCore(normalized);
      if (core != null) {
        results.add(
          ColumnMapping(
            index: i,
            sourceHeader: header,
            normalizedHeader: normalized,
            kind: ColumnTargetKind.core,
            status: ColumnMatchStatus.autoMatched,
            coreField: core,
          ),
        );
        continue;
      }

      final custom = _matchExistingCustom(normalized, customFields);
      if (custom != null) {
        results.add(
          ColumnMapping(
            index: i,
            sourceHeader: header,
            normalizedHeader: normalized,
            kind: ColumnTargetKind.custom,
            status: ColumnMatchStatus.autoMatched,
            customFieldName: custom.fieldName,
            customDisplayName: custom.displayName,
            customEntityType: custom.entityType,
            customDataType: custom.dataType,
          ),
        );
        continue;
      }

      final suggestion = _suggestCore(normalized);
      if (suggestion != null) {
        results.add(
          ColumnMapping(
            index: i,
            sourceHeader: header,
            normalizedHeader: normalized,
            kind: ColumnTargetKind.core,
            status: ColumnMatchStatus.suggested,
            coreField: suggestion,
          ),
        );
        continue;
      }

      final slug = _uniqueSlug(normalized, usedSlugs);
      results.add(
        ColumnMapping(
          index: i,
          sourceHeader: header,
          normalizedHeader: normalized,
          kind: ColumnTargetKind.custom,
          status: ColumnMatchStatus.unknown,
          customFieldName: slug,
          customDisplayName: header,
          customEntityType: 'student',
        ),
      );
    }
    return results;
  }

  static ImportCoreField? _exactCore(String normalized) {
    for (final entry in _normalizedAliases.entries) {
      if (entry.value.contains(normalized)) return entry.key;
    }
    return null;
  }

  static CustomFieldDefinition? _matchExistingCustom(
    String normalized,
    List<CustomFieldDefinition> customFields,
  ) {
    for (final field in customFields) {
      if (normalizeHeader(field.fieldName.replaceAll('_', ' ')) == normalized ||
          normalizeHeader(field.displayName) == normalized) {
        return field;
      }
    }
    return null;
  }

  /// A conservative "sounds related" match — only whole normalized words. The
  /// longest matching alias wins so "Student Admission Number" is suggested as
  /// Admission Number, not Student.
  static ImportCoreField? _suggestCore(String normalized) {
    ImportCoreField? best;
    var bestLength = 0;
    for (final entry in _normalizedAliases.entries) {
      for (final alias in entry.value) {
        if (alias.length < 4) continue;
        final matches =
            normalized == alias ||
            normalized.contains(' $alias') ||
            normalized.startsWith('$alias ') ||
            normalized.endsWith(' $alias');
        if (matches && alias.length > bestLength) {
          best = entry.key;
          bestLength = alias.length;
        }
      }
    }
    return best;
  }

  static String _uniqueSlug(String normalized, Set<String> used) {
    var slug = normalized.replaceAll(' ', '_');
    if (!used.contains(slug)) {
      used.add(slug);
      return slug;
    }
    var suffix = 2;
    while (used.contains('${slug}_$suffix')) {
      suffix += 1;
    }
    final unique = '${slug}_$suffix';
    used.add(unique);
    return unique;
  }
}
