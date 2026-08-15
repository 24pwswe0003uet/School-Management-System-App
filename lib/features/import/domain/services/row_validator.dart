import '../entities/column_mapping.dart';
import '../entities/custom_field.dart';
import '../entities/import_fields.dart';
import '../entities/import_row.dart';

/// Parses and validates one imported row against its column mappings. Custom
/// (unknown) columns are lenient by design — they never invalidate a row.
class RowValidator {
  /// Parses [raw] into a typed value for [field], appending [ImportRowError]s
  /// for unparseable input. Mutates [row].
  void validateRow(ImportRow row, List<ColumnMapping> columns) {
    row.errors.clear();
    row.coreValues.clear();
    row.customValues.clear();

    for (final column in columns) {
      final raw = column.index < row.rawValues.length
          ? row.rawValues[column.index]
          : null;
      switch (column.kind) {
        case ColumnTargetKind.ignored:
          break;
        case ColumnTargetKind.core:
          _validateCore(row, column, raw);
        case ColumnTargetKind.custom:
          final text = _toText(raw);
          if (text != null && text.isNotEmpty) {
            row.customValues[column.customFieldName!] = _parseCustomValue(
              text,
              column.customDataType,
            );
          }
      }
    }

    final name = row.coreValues[ImportCoreField.studentName] as String?;
    if (name == null || name.trim().isEmpty) {
      row.errors.add(const ImportRowError('Student Name', 'is required.'));
    }
  }

  void _validateCore(ImportRow row, ColumnMapping column, Object? raw) {
    final field = column.coreField!;
    switch (field) {
      case ImportCoreField.studentName:
        final value = _toText(raw);
        if (value != null && value.isNotEmpty) {
          row.coreValues[field] = value.trim();
        }
      case ImportCoreField.gender:
        final value = _toText(raw);
        if (value == null || value.trim().isEmpty) break;
        final gender = _parseGender(value);
        if (gender == null) {
          row.errors.add(
            const ImportRowError('Gender', 'must be Male, Female or Other.'),
          );
        } else {
          row.coreValues[field] = gender;
        }
      case ImportCoreField.dateOfBirth:
      case ImportCoreField.admissionDate:
        final value = _toText(raw);
        if (value == null || value.trim().isEmpty) break;
        final date = _parseDate(value) ?? (raw is DateTime ? raw : null);
        if (date == null) {
          row.errors.add(
            ImportRowError(
              field.displayName,
              'is not a valid date (e.g. 15/08/2026).',
            ),
          );
        } else {
          row.coreValues[field] = DateTime(date.year, date.month, date.day);
        }
      case ImportCoreField.admissionFee:
        final value = _toText(raw);
        if (value == null || value.trim().isEmpty) break;
        final amount = _parseNumber(value);
        if (amount == null || amount < 0) {
          row.errors.add(
            const ImportRowError(
              'Admission Fee',
              'must be a number of 0 or more.',
            ),
          );
        } else {
          row.coreValues[field] = amount;
        }
      case ImportCoreField.cnic:
        final value = _toText(raw);
        if (value == null || value.trim().isEmpty) break;
        row.coreValues[field] = _normalizeCnic(value.trim());
      case ImportCoreField.existingFamilyId:
      case ImportCoreField.studentId:
        final value = _toText(raw);
        if (value != null && value.trim().isNotEmpty) {
          row.coreValues[field] = value.trim();
        }
      case ImportCoreField.guardianName:
      case ImportCoreField.motherName:
      case ImportCoreField.primaryPhone:
      case ImportCoreField.secondaryPhone:
      case ImportCoreField.address:
      case ImportCoreField.contactReference:
      case ImportCoreField.notes:
      case ImportCoreField.className:
      case ImportCoreField.section:
      case ImportCoreField.admissionNumber:
        final value = _toText(raw);
        if (value != null && value.trim().isNotEmpty) {
          row.coreValues[field] = value.trim();
        }
    }
  }

  /// Infers a [CustomFieldDataType] from the non-empty values of one column.
  CustomFieldDataType inferCustomType(
    List<List<Object?>> sheetRows,
    int column,
  ) {
    final values = <String>[];
    for (final row in sheetRows) {
      final text = column < row.length ? _toText(row[column]) : null;
      if (text != null && text.trim().isNotEmpty) values.add(text.trim());
    }
    if (values.isEmpty) return CustomFieldDataType.text;

    final bools = {'yes', 'no', 'true', 'false', 'y', 'n', '1', '0'};
    if (values.every((v) => bools.contains(v.toLowerCase()))) {
      return CustomFieldDataType.boolean;
    }
    if (values.every((v) => _parseIntStrict(v) != null)) {
      return CustomFieldDataType.number;
    }
    if (values.every((v) => _parseNumber(v) != null)) {
      return CustomFieldDataType.decimal;
    }
    if (values.every((v) => _parseDate(v) != null)) {
      return CustomFieldDataType.date;
    }
    return CustomFieldDataType.text;
  }

  static Object? _parseCustomValue(String text, CustomFieldDataType? type) {
    switch (type) {
      case CustomFieldDataType.number:
        final parsed = _parseIntStrict(text);
        if (parsed != null) return parsed;
        final num = _parseNumber(text);
        if (num != null && num == num.roundToDouble()) return num.toInt();
        return text;
      case CustomFieldDataType.decimal:
        return _parseNumber(text) ?? text;
      case CustomFieldDataType.date:
        return _parseDate(text) ?? text;
      case CustomFieldDataType.boolean:
        final normalized = text.trim().toLowerCase();
        if (normalized == 'yes' || normalized == 'true' || normalized == 'y') {
          return true;
        }
        if (normalized == 'no' || normalized == 'false' || normalized == 'n') {
          return false;
        }
        return text;
      case CustomFieldDataType.text:
      case null:
        return text;
    }
  }

  static String? _parseGender(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'male' || 'm' => 'male',
      'female' || 'f' => 'female',
      'other' || 'o' => 'other',
      _ => null,
    };
  }

  static String? _normalizeCnic(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 13) return value.trim();
    return '${digits.substring(0, 5)}-${digits.substring(5, 12)}-'
        '${digits.substring(12)}';
  }

  static DateTime? _parseDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final patterns = <(RegExp, String)>[
      (RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$'), 'ymd'),
      (RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$'), 'ymd'),
      (RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$'), 'dmy'),
      (RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})$'), 'dmy'),
      (RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$'), 'dmy'),
    ];
    for (final (regex, mode) in patterns) {
      final match = regex.firstMatch(text);
      if (match == null) continue;
      final a = int.tryParse(match.group(1)!);
      final b = int.tryParse(match.group(2)!);
      final c = int.tryParse(match.group(3)!);
      if (a == null || b == null || c == null) continue;
      final (y, m, d) = mode == 'dmy' ? (c, b, a) : (a, b, c);
      if (m < 1 || m > 12 || d < 1 || d > 31) return null;
      try {
        return DateTime(y, m, d);
      } catch (_) {
        return null;
      }
    }
    final parsed = DateTime.tryParse(text);
    return parsed;
  }

  static double? _parseNumber(String value) {
    final cleaned = value.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  static int? _parseIntStrict(String value) {
    final cleaned = value.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    if (!RegExp(r'^-?\d+$').hasMatch(cleaned)) return null;
    return int.tryParse(cleaned);
  }

  static String? _toText(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is DateTime) return value.toIso8601String();
    return value.toString();
  }
}
