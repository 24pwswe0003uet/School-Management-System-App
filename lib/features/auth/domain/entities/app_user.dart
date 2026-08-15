import 'app_role.dart';

/// The signed-in office user. Password material is intentionally NOT part of
/// this entity — it stays inside the data layer.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String username;
  final String displayName;
  final AppRole role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}
