/// Fallback for platforms with no SQLite backend.
void initDatabaseFactory() {
  throw UnsupportedError('SQLite is not supported on this platform.');
}
