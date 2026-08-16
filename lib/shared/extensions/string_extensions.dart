// String extensions for the application
extension StringExtensions on String {
  String capitalizeFirst() => [this[0].toUpperCase(), substring(1)].join();
}