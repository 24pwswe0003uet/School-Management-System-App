import '../entities/app_role.dart';
import '../entities/app_user.dart';

/// Abstraction over local credential storage so the session/service layer
/// never touches SQL directly.
abstract interface class AuthRepository {
  /// Verifies [identifier] + [password] against the local database.
  ///
  /// Returns the authenticated [AppUser] on success, or `null` for a wrong
  /// password, an unknown account, or an inactive account (all indistinguishable
  /// to the caller on purpose).
  Future<AppUser?> authenticate(String identifier, String password);

  /// Creates a user account. The password is hashed before storage.
  Future<AppUser> createUser({
    required String username,
    required String password,
    required String displayName,
    AppRole role,
  });

  /// Whether at least one account exists (drives first-run setup).
  Future<bool> hasAnyUser();
}
