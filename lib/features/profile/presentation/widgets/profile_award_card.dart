import 'package:flutter/material.dart' hide Badge;

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/user_service.dart';

/// Single badge tile on the profile awards grid (Z-ARCH-002).
class ProfileAwardCard extends StatelessWidget {
  const ProfileAwardCard({
    super.key,
    required this.badge,
    required this.isEarned,
  });

  final Badge badge;
  final bool isEarned;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEarned ? 1.0 : 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: isEarned ? AppColors.surfaceV2 : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isEarned
                ? AppColors.signal.withValues(alpha: 0.08)
                : AppColors.surfaceV2,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(badge.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              badge.name,
              style: AppTextStyles.h5.copyWith(
                fontSize: 13,
                color: isEarned
                    ? AppColors.signal
                    : AppColors.textV2Secondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              badge.description,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: AppColors.textV2Tertiary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
