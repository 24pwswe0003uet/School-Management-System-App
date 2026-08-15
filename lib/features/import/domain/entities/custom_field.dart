/// The data types a custom field can store. Values are persisted as text and
/// typed only at the application layer.
enum CustomFieldDataType {
  text,
  number,
  decimal,
  date,
  boolean;

  String get dbValue => name;

  static CustomFieldDataType fromDb(String value) =>
      CustomFieldDataType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => CustomFieldDataType.text,
      );

  String get label => switch (this) {
    CustomFieldDataType.text => 'Text',
    CustomFieldDataType.number => 'Whole number',
    CustomFieldDataType.decimal => 'Decimal number',
    CustomFieldDataType.date => 'Date',
    CustomFieldDataType.boolean => 'Yes/No',
  };
}

/// A user-defined field, created automatically when an imported workbook
/// contains an unknown column. Lives in `custom_field_definitions`.
class CustomFieldDefinition {
  const CustomFieldDefinition({
    required this.id,
    required this.definitionId,
    required this.entityType,
    required this.fieldName,
    required this.displayName,
    required this.dataType,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String definitionId;
  final String entityType;
  final String fieldName;
  final String displayName;
  final CustomFieldDataType dataType;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// The value of a custom field for one record. Lives in
/// `custom_field_values`.
class CustomFieldValue {
  const CustomFieldValue({
    required this.id,
    required this.definitionId,
    required this.entityType,
    required this.entityId,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int definitionId;
  final String entityType;
  final int entityId;
  final String? value;
  final DateTime createdAt;
  final DateTime updatedAt;
}
