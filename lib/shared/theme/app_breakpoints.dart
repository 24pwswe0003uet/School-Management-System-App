import 'package:flutter/material.dart';

/// Responsive screen size breakpoints.
abstract final class AppBreakpoints {
  static const double phone = 600;
  static const double tablet = 1024;

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < phone;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= phone && width <= tablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width > tablet;
}
