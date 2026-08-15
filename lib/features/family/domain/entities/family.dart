/// Archive state of a family.
enum FamilyStatus {
  active,
  inactive;

  String get label => switch (this) {
    FamilyStatus.active => 'Active',
    FamilyStatus.inactive => 'Archived',
  };

  static FamilyStatus fromDb(String value) =>
      value == 'inactive' ? FamilyStatus.inactive : FamilyStatus.active;
}

/// A household/guardian record. Multiple students can belong to one family;
/// family information is stored once here, never duplicated into students.
class Family {
  const Family({
    required this.id,
    required this.familyId,
    required this.guardianName,
    required this.motherName,
    required this.primaryPhone,
    required this.secondaryPhone,
    required this.address,
    required this.cnic,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String familyId;
  final String guardianName;
  final String? motherName;
  final String? primaryPhone;
  final String? secondaryPhone;
  final String? address;
  final String? cnic;
  final String? notes;
  final FamilyStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => status == FamilyStatus.inactive;

  Family copyWith({FamilyStatus? status}) => Family(
    id: id,
    familyId: familyId,
    guardianName: guardianName,
    motherName: motherName,
    primaryPhone: primaryPhone,
    secondaryPhone: secondaryPhone,
    address: address,
    cnic: cnic,
    notes: notes,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
