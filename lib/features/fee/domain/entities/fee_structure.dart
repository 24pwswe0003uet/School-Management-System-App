/// A fee structure/rule that "Generate monthly fee" resolves against.
///
/// One rule per class (stored in `className`) plus one global default rule
/// (`className` is null). Generation picks the student's class rule first and
/// falls back to the global default; a student with neither is skipped and
/// reported is reported.
enum FeeType {
  admission,
  monthly;

  String get label =>
      switch (this) {
        FeeType.admission => 'Admission',
        FeeType.monthly => 'Monthly',
      };

  String get dbValue =>
      switch (this) {
        FeeType.admission => 'admission',
        FeeType.monthly => 'monthly',
      };
}

/// A fee structure/rule that "Generate monthly fee" resolves against.
///
/// One rule per class (stored in `className`) plus one global default rule
/// (`className` is null). Generation picks the student's class rule first and
/// falls back to the global default; a student with neither is skipped and
/// reported is reported.
class FeeStructure {
  const FeeStructure({
    required this.id,
    required this.structureId,
    required this.name,
    this.description,
    this.className,
    required this.monthlyAmount,
    required this.discountAmount,
    required this.feeType,
    required this.isActive,
  });

  /// Admission or Monthly.
  final FeeType feeType;

  final int id;
  final String structureId;
  final String name;
  final String? description;
  final String? className;
  final double monthlyAmount;
  final double discountAmount;
  final bool isActive;

  bool get isDefault =>
      className == null && feeType == FeeType.monthly;
}