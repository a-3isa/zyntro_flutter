import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';

/// Compact visitor status chip on profile header (Z-ARCH-002).
class ProfileVisitorChip extends StatelessWidget {
  const ProfileVisitorChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.7,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

/// Workouts / streak / followers / following row (Z-ARCH-002).
class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    super.key,
    required this.workouts,
    required this.streak,
    required this.followers,
    required this.following,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  final int workouts;
  final int streak;
  final int followers;
  final int following;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  @override
  Widget build(BuildContext context) {
    final stats =
        <({String label, String value, String? emoji, VoidCallback? onTap})>[
          (
            label: 'Workouts',
            value: workouts.toString(),
            emoji: null,
            onTap: null,
          ),
          (label: 'Streak', value: streak.toString(), emoji: '🔥', onTap: null),
          (
            label: 'Followers',
            value: followers.toString(),
            emoji: null,
            onTap: onFollowersTap,
          ),
          (
            label: 'Following',
            value: following.toString(),
            emoji: null,
            onTap: onFollowingTap,
          ),
        ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceV2Active),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: List.generate(stats.length * 2 - 1, (i) {
            if (i.isOdd) {
              return VerticalDivider(
                color: AppColors.surfaceV2,
                width: 1,
                thickness: 1,
              );
            }
            final s = stats[i ~/ 2];
            final tappable = s.onTap != null;
            final cellContent = Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.value,
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textV2Primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (s.emoji != null) ...[
                        const SizedBox(width: 2),
                        Text(s.emoji!, style: const TextStyle(fontSize: 14)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.label,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.textV2Tertiary,
                    ),
                  ),
                ],
              ),
            );
            return Expanded(
              child: tappable
                  ? GestureDetector(
                      onTap: s.onTap,
                      behavior: HitTestBehavior.opaque,
                      child: cellContent,
                    )
                  : cellContent,
            );
          }),
        ),
      ),
    );
  }
}
