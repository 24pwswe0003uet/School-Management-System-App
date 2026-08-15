import '../../../../core/database/app_database.dart';
import '../../../../core/services/secure_password_service.dart';
import '../../domain/entities/app_role.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._db, {SecurePasswordService? passwordService})
    : _passwordService = passwordService ?? SecurePasswordService();

  final AppDatabase _db;
  final SecurePasswordService _passwordService;

  /// A real, well-formed hash used to equalise verification timing when the
  /// account does not exist, so response time does not reveal account status.
  static final String _dummyHash = SecurePasswordService().hashPassword(
    'dummy-password-for-timing',
  );

  @override
  Future<AppUser?> authenticate(String identifier, String password) async {
    final username = identifier.trim();
    final rows = await _db.raw.rawQuery(
      'SELECT * FROM users WHERE username = ? COLLATE NOCASE',
      [username],
    );

    if (rows.isEmpty) {
      _passwordService.verifyPassword(password, _dummyHash);
      return null;
    }

    final row = rows.first;
    final valid = _passwordService.verifyPassword(
      password,
      row['password_hash'] as String,
    );
    if (!valid) {
      return null;
    }
    if (row['is_active'] != 1) {
      return null;
    }
    return _fromRow(row);
  }

  @override
  Future<AppUser> createUser({
    required String username,
    required String password,
    required String displayName,
    AppRole role = AppRole.dataEntry,
  }) async {
    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();
    final id = await _db.raw.insert('users', {
      'username': username.trim(),
      'password_hash': _passwordService.hashPassword(password),
      'display_name': displayName.trim(),
      'role': role.dbValue,
      'is_active': 1,
      'created_at': nowIso,
      'updated_at': nowIso,
    });

    return AppUser(
      id: id,
      username: username.trim(),
      displayName: displayName.trim(),
      role: role,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<bool> hasAnyUser() async {
    final rows = await _db.raw.rawQuery('SELECT COUNT(*) AS count FROM users');
    final count = rows.first['count'] as int? ?? 0;
    return count > 0;
  }

  AppUser _fromRow(Map<String, Object?> row) => AppUser(
    id: row['id'] as int,
    username: row['username'] as String,
    displayName: row['display_name'] as String,
    role: AppRole.fromDbValue(row['role'] as String),
    isActive: row['is_active'] == 1,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}
