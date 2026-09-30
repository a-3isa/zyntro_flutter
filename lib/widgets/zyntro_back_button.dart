import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';

/// 48px back control used on settings, profile, and legal screens.
class ZyntroBackButton extends StatelessWidget {
  const ZyntroBackButton({
    super.key,
    this.onPressed,
    this.tooltip = 'Back',
    this.icon = Icons.arrow_back,
  });

  final VoidCallback? onPressed;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: () {
        HapticFeedback.lightImpact();
        if (onPressed != null) {
          onPressed!();
        } else {
          Navigator.maybePop(context);
        }
      },
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textV2Primary,
        backgroundColor: AppColors.surfaceV2Elevated,
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 20, color: AppColors.textV2Primary),
    );
  }
}
