/// Thrown when an attempt is made to permanently delete a family that still
/// has linked students. Per the specification such families are never deleted;
/// the UI offers archiving instead.
class FamilyHasLinkedStudentsException implements Exception {
  const FamilyHasLinkedStudentsException(this.familyId);

  final String familyId;

  @override
  String toString() =>
      'Family $familyId cannot be deleted because it still has linked students.';
}
