/// Global application configuration and branding constants.
abstract final class AppConfig {
  static const String appName = 'School Office Management System';
  static const String appShortName = 'School Office';

  static const int setupPasswordMinLength = 6;

  /// Default currency symbol for money display. A settings module can make
  /// this configurable later; until then all amounts are shown with it.
  static const String currencySymbol = 'Rs';
}
