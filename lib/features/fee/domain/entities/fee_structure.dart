/// A fee structure/rule that "Generate monthly fee" resolves against.
///
/// One rule per class (stored in `class_name`) plus one global default rule
/// (`class_name` is null). Generation picks the student's class rule first and
/// falls back to the global default; a student with neither is skipped and
/// reported.
class FeeStructure {
  const FeeStructure({
    required this.id,
    required this.structureId,
    required this.name,
    this.description,
    this.className,
    required this.monthlyAmount,
    required this.discountAmount,
    required this.isActive,
  });

  final int id;
  final String structureId;
  final String name;
  final String? description;
  final String? className;
  final double monthlyAmount;
  final double discountAmount;
  final bool isActive;

  bool get isDefault => className == null;
}
