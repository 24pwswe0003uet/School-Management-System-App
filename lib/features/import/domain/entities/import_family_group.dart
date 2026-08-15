/// How a proposed family relates to families already in the database.
enum ImportFamilyMatch {
  /// No existing family matches; a new family will be created.
  none,

  /// An existing family shares a strong signal (phone/CNIC/address); flagged
  /// for the operator instead of being silently merged.
  possibleDuplicate,

  /// The row referenced an existing family by its family ID.
  existing,
}

/// A group of imported student rows that share one family record. Grouping
/// uses the strongest available signal (CNIC, then phone, then guardian name)
/// — a shared name alone never merges distinct families.
class ImportFamilyGroup {
  ImportFamilyGroup({required this.guardianName});

  final String guardianName;
  String? motherName;
  String? primaryPhone;
  String? secondaryPhone;
  String? address;
  String? cnic;

  /// 0-based data-row indices that belong to this group.
  final List<int> rowIndices = [];

  /// Custom field values for the family (keyed by field name).
  final Map<String, Object?> customValues = {};

  ImportFamilyMatch match = ImportFamilyMatch.none;
  int? matchedFamilyDbId;
  String? matchMessage;

  int get studentCount => rowIndices.length;

  /// Deterministic grouping key: the strongest signal present wins.
  static String groupKeyFor({
    required String guardianName,
    String? cnic,
    String? primaryPhone,
  }) {
    final cnicDigits = (cnic ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (cnicDigits.length == 13) return 'c:$cnicDigits';
    final phoneDigits = (primaryPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (phoneDigits.isNotEmpty) return 'p:$phoneDigits';
    return 'g:${guardianName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}';
  }
}
