/// Outcome of a "Generate monthly fee" run. Generation is idempotent: a
/// student that already has a record for the month is reported, never doubled.
class FeeGenerationResult {
  const FeeGenerationResult({
    required this.created,
    required this.alreadyExists,
    required this.noRule,
  });

  final int created;
  final int alreadyExists;
  final int noRule;

  bool get isEmpty => created == 0 && alreadyExists == 0 && noRule == 0;
}
