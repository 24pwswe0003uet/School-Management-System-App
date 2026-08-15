import 'package:flutter/foundation.dart';

import '../entities/app_role.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

/// Outcome of an authentication attempt. UI maps these to user-facing
/// messages; credential failures are deliberately collapsed into one case so
/// nothing is revealed about which credential was wrong.
enum AuthResult { success, invalidCredentials, databaseError }

/// Holds the in-memory session for the application and exposes the
/// authentication operations used by screens.
///
/// The session is intentionally not persisted: per the specification the user
/// must log in again on every fresh launch of the application.
class AuthService extends ChangeNotifier {
  AuthService(this._repository);

  final AuthRepository _repository;

  AppUser? _currentUser;
  bool _setupRequired = true;

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get setupRequired => _setupRequired;

  /// Re-checks whether an account exists yet (used on startup and after a
  /// restore). Called once during bootstrap.
  Future<void> refreshSetupStatus() async {
    _setupRequired = !await _repository.hasAnyUser();
    notifyListeners();
  }

  Future<AuthResult> login(String identifier, String password) async {
    try {
      final user = await _repository.authenticate(identifier, password);
      if (user == null) {
        return AuthResult.invalidCredentials;
      }
      _currentUser = user;
      notifyListeners();
      return AuthResult.success;
    } catch (_) {
      return AuthResult.databaseError;
    }
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  /// Creates the first administrator account. Does not flip [setupRequired];
  /// call [completeSetup] after the user has acknowledged the success message.
  Future<AuthResult> createInitialAdmin({
    required String displayName,
    required String username,
    required String password,
  }) async {
    try {
      await _repository.createUser(
        username: username,
        password: password,
        displayName: displayName,
        role: AppRole.schoolAdmin,
      );
      return AuthResult.success;
    } catch (_) {
      return AuthResult.databaseError;
    }
  }

  void completeSetup() {
    _setupRequired = false;
    notifyListeners();
  }
}
