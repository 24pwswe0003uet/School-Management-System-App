import 'migration.dart';

/// Schema version 3: extends the Module 2 `families` table with the fields the
/// Family Management module needs — an optional CNIC, an archive status, and
/// search indexes. All statements are additive so existing databases upgrade
/// in place.
const Migration migrationV3 = Migration(
  version: 3,
  statements: [
    // CNIC is optional ("if the school chooses to store it").
    'ALTER TABLE families ADD COLUMN cnic TEXT',
    // Archive behavior: a family with linked students is never hard-deleted.
    "ALTER TABLE families ADD COLUMN status TEXT NOT NULL DEFAULT 'active' "
        "CHECK (status IN ('active', 'inactive'))",
    'CREATE INDEX idx_families_guardian_name ON families(guardian_name)',
    'CREATE INDEX idx_families_mother_name ON families(mother_name)',
    'CREATE INDEX idx_families_phone ON families(phone)',
    'CREATE INDEX idx_families_alternate_phone ON families(alternate_phone)',
    'CREATE INDEX idx_families_status ON families(status)',
  ],
);
