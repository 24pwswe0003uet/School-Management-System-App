import 'family.dart';

/// A family row in the search/list results. The student count helps the user
/// distinguish families that share similar names or addresses.
class FamilyListItem {
  const FamilyListItem({required this.family, required this.studentCount});

  final Family family;
  final int studentCount;
}
