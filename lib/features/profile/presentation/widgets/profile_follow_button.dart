import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/follow_service.dart';
import '../../../auth/auth_providers.dart';
import '../profile_providers.dart';

/// Follow / request / unfollow CTA on profile (Z-ARCH-002).
class ProfileFollowButton extends ConsumerWidget {
  const ProfileFollowButton({
    super.key,
    required this.targetUserId,
    required this.isTargetPrivate,
    required this.isLoading,
    this.followsMe = false,
    required this.onFollow,
    required this.onUnfollow,
  });

  final String targetUserId;
  final bool isTargetPrivate;
  final bool isLoading;
  final bool followsMe;
  final void Function(String, bool) onFollow;
  final void Function(String) onUnfollow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followStatusAsync = ref.watch(followStatusProvider(targetUserId));
    final currentUserId = ref.watch(authCurrentUserIdProvider);

    return followStatusAsync.when(
      data: (status) {
        final bool isPrimary =
            status == null || status == FollowStatus.declined;
        final String buttonText = switch (status) {
          FollowStatus.pending => 'REQUESTED',
          FollowStatus.approved => 'FOLLOWING',
          _ => followsMe ? 'Follow back' : 'FOLLOW',
        };
        final VoidCallback? onPressed = switch (status) {
          FollowStatus.pending =>
            currentUserId == null
                ? null
                : () async {
                    await ref
                        .read(followServiceProvider)
                        .withdrawFollowRequest(currentUserId, targetUserId);
                    ref.invalidate(followStatusProvider(targetUserId));
                  },
          FollowStatus.approved => () => onUnfollow(targetUserId),
          _ => () => onFollow(targetUserId, isTargetPrivate),
        };

        return GestureDetector(
          onTap: isLoading ? null : onPressed,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isPrimary ? AppColors.signal : AppColors.surfaceV2,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              border: isPrimary
                  ? null
                  : Border.all(color: AppColors.surfaceV2Active),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isPrimary
                            ? AppColors.backgroundV2
                            : AppColors.signal,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: AppTextStyles.label.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isPrimary
                            ? AppColors.backgroundV2
                            : AppColors.textV2Primary,
                        letterSpacing: 0.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
            ),
          ),
        );
      },
      loading: () => SizedBox(
        height: 50,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.signal,
          ),
        ),
      ),
      error: (_, _) => GestureDetector(
        onTap: () => onFollow(targetUserId, isTargetPrivate),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.signal,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          child: Center(
            child: Text(
              'FOLLOW',
              style: AppTextStyles.label.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.backgroundV2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
