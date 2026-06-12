import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Unified avatar widget — photoUrl with initials fallback.
class FluttermojiAvatar extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final double size;
  final VoidCallback? onTap;
  final bool showGradientBorder;
  final Color? ringColor;

  const FluttermojiAvatar({
    super.key,
    this.photoUrl,
    required this.displayName,
    this.size = 40,
    this.onTap,
    this.showGradientBorder = true,
    this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    Widget avatarWidget;

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      avatarWidget = CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.surfaceV2Elevated,
        backgroundImage: NetworkImage(photoUrl!),
        onBackgroundImageError: (_, _) {},
        child: null,
      );
    } else {
      avatarWidget = CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.surfaceV2Elevated,
        child: Text(
          initial,
          style: TextStyle(
            color: AppColors.textV2Primary,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (showGradientBorder) {
      avatarWidget = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ringColor ?? AppColors.userAccent,
        ),
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.backgroundV2,
          ),
          padding: const EdgeInsets.all(2),
          child: avatarWidget,
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatarWidget);
    }

    return avatarWidget;
  }
}
