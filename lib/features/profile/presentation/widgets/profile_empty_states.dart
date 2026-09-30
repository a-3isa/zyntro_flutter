import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';

/// Empty posts grid state extracted from profile god file (Z-ARCH-002).
class ProfileEmptyPosts extends StatelessWidget {
  const ProfileEmptyPosts({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: AppColors.textV2Tertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'No posts yet',
            style: AppTextStyles.h5.copyWith(
              fontSize: 16,
              color: AppColors.textV2Secondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Private-account locked posts state (Z-ARCH-002).
class ProfilePrivateLocked extends StatelessWidget {
  const ProfilePrivateLocked({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 48,
            color: AppColors.textV2Tertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'This account is private',
            style: AppTextStyles.h5.copyWith(
              fontSize: 16,
              color: AppColors.textV2Secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Follow to see posts',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textV2Tertiary,
            ),
          ),
        ],
      ),
    );
  }
}
