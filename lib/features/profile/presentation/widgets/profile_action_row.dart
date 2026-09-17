import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../profile_providers.dart';
import 'profile_history_widgets.dart';

/// Owner-only edit + weekly goal row (Z-ARCH-002).
class ProfileActionRow extends ConsumerWidget {
  const ProfileActionRow({
    super.key,
    required this.postCount,
    required this.targetUserId,
  });

  final int postCount;
  final String targetUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(userSessionsProvider(targetUserId));
    final userAsync = ref.watch(currentUserProfileProvider);
    final trainingDaysGoal = (userAsync.value == null ? null : null) ?? 4;

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );
    final weeklyDone =
        sessionsAsync.value
            ?.where((s) => s.startedAt.isAfter(weekStart))
            .length ??
        0;
    final weeklyGoal = trainingDaysGoal;
    final progress = (weeklyDone / weeklyGoal).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          PressableRow(
            onTap: () => context.push(AppRoutes.editProfile),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceV2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: AppColors.textV2Secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Edit Profile',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 13,
                      color: AppColors.textV2Primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceV2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'THIS WEEK',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textV2Tertiary,
                        ),
                      ),
                      Text(
                        '$weeklyDone / $weeklyGoal',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: weeklyDone >= weeklyGoal
                              ? AppColors.signal
                              : AppColors.textV2Secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: AppColors.surfaceV2Elevated,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.signal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
