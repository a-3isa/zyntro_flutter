import 'package:flutter/material.dart';
import 'package:avatar_plus/avatar_plus.dart';

import '../core/theme/app_theme.dart';

/// Unified avatar widget that supports both custom avatars and fallback to photoURL/initials
class FluttermojiAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? avatarConfig;
  final String displayName;
  final double size;
  final VoidCallback? onTap;
  final bool showGradientBorder;

  const FluttermojiAvatar({
    super.key,
    this.photoUrl,
    this.avatarConfig,
    required this.displayName,
    this.size = 40,
    this.onTap,
    this.showGradientBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    Widget avatarWidget;

    // Priority: avatarConfig > photoUrl > initials
    if (avatarConfig != null && avatarConfig!.isNotEmpty) {
      // Use custom avatar from config (avatar_plus generated)
      avatarWidget = ClipOval(
        child: AvatarPlus(avatarConfig!, height: size, width: size),
      );
    } else if (photoUrl != null && photoUrl!.isNotEmpty) {
      // Use network image (for social auth or uploaded photos)
      avatarWidget = CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.surfaceSecondaryDark,
        backgroundImage: NetworkImage(photoUrl!),
        onBackgroundImageError: (exception, stackTrace) {
          // Fallback handled by child
        },
        child: null,
      );
    } else {
      // Fallback to text initials
      avatarWidget = CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.surfaceSecondaryDark,
        child: Text(
          initial,
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Wrap with gradient border if enabled
    if (showGradientBorder) {
      avatarWidget = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: AppColors.primaryGradient),
        ),
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.backgroundDark,
          ),
          padding: const EdgeInsets.all(2),
          child: avatarWidget,
        ),
      );
    }

    // Wrap with GestureDetector if onTap provided
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatarWidget);
    }

    return avatarWidget;
  }
}
