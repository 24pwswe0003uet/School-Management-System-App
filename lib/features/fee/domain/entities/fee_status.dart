/// Payment status of a fee record. The database keeps the v2 codes
/// (`pending`/`partial`/`paid`); this enum is the module's view of them.
enum FeeStatus {
  unpaid,
  partial,
  paid;

  static FeeStatus fromDb(String value) {
    return switch (value) {
      'partial' => FeeStatus.partial,
      'paid' => FeeStatus.paid,
      _ => FeeStatus.unpaid,
    };
  }

  String get dbValue => switch (this) {
        FeeStatus.unpaid => 'pending',
        FeeStatus.partial => 'partial',
        FeeStatus.paid => 'paid',
      };

  String get label => switch (this) {
        FeeStatus.unpaid => 'Unpaid',
        FeeStatus.partial => 'Partially Paid',
        FeeStatus.paid => 'Paid',
      };
}
