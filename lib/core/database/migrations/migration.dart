/// A single database migration.
///
/// Migrations are applied in order of [version] and are tracked in the
/// `schema_versions` table so they are never applied twice.
class Migration {
  const Migration({required this.version, required this.statements});

  final int version;
  final List<String> statements;
}
