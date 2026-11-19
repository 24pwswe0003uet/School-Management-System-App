import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Reusable status chip rendering semantic colors for school statuses.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    this.color,
    this.backgroundColor,
    this.isSuccess = false,
    this.isWarning = false,
    this.isDanger = false,
    this.isInfo = false,
    this.icon,
  });

  final String label;
  final Color? color;
  final Color? backgroundColor;
  final bool isSuccess;
  final bool isWarning;
  final bool isDanger;
  final bool isInfo;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    Color effectiveFg = color ?? AppTheme.secondarySlate;
    Color effectiveBg = backgroundColor ?? const Color(0xFFF1F5F9);

    if (isSuccess) {
      effectiveFg = AppTheme.successGreen;
      effectiveBg = AppTheme.successBg;
    } else if (isWarning) {
      effectiveFg = AppTheme.warningAmber;
      effectiveBg = AppTheme.warningBg;
    } else if (isDanger) {
      effectiveFg = AppTheme.dangerRed;
      effectiveBg = AppTheme.dangerBg;
    } else if (isInfo) {
      effectiveFg = AppTheme.infoSky;
      effectiveBg = AppTheme.infoBg;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: effectiveFg.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: effectiveFg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: effectiveFg,
            ),
          ),
        ],
      ),
    );
  }
}
