import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/user_service.dart';
import '../../../../utils/haptic_manager.dart';
import '../../../../utils/image_cache_manager.dart';

/// Buddy list row extracted from social god file (Z-ARCH-002).
class SocialBuddyRow extends StatelessWidget {
  const SocialBuddyRow({super.key, required this.buddy});

  final BuddyWithPresence buddy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticManager.light();
        context.push('/user/${buddy.id}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceV2Elevated,
                  ),
                  child: ClipOval(
                    child: buddy.photoURL != null
                        ? CachedNetworkImage(
                            imageUrl: buddy.photoURL!,
                            cacheManager: ZyntroImageCacheManager(),
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Text(
                              buddy.displayName.isNotEmpty
                                  ? buddy.displayName[0].toUpperCase()
                                  : '?',
                              style: AppTextStyles.h5.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textV2Primary,
                              ),
                            ),
                          ),
                  ),
                ),
                if (buddy.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.backgroundV2,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    buddy.displayName,
                    style: AppTextStyles.h5.copyWith(
                      fontSize: 15,
                      color: AppColors.textV2Primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    buddy.isOnline ? 'Online now' : 'Offline',
                    style: AppTextStyles.caption.copyWith(
                      color: buddy.isOnline
                          ? AppColors.success
                          : AppColors.textV2Secondary,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticManager.light();
                context.push('/user/${buddy.id}');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceV2,
                  border: Border.all(color: AppColors.surfaceV2Active),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Following',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 13,
                    color: AppColors.textV2Secondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading placeholder for buddy rows (Z-ARCH-002).
class SocialBuddySkeleton extends StatelessWidget {
  const SocialBuddySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceV2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 13,
                  width: 110,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceV2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 11,
                  width: 70,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceV2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 82,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceV2,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }
}

/// Facebook connect CTA on Find tab (Z-ARCH-002).
class SocialFacebookConnectBanner extends StatelessWidget {
  const SocialFacebookConnectBanner({
    super.key,
    required this.onConnect,
    required this.onDismiss,
  });

  final VoidCallback onConnect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.brandFacebook.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.brandFacebook.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.people_alt_outlined,
              color: AppColors.brandFacebook,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find friends from Facebook',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textV2Primary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    "Connect to see who's already on Zyntro",
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textV2Secondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onConnect,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brandFacebook,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Connect',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(
                Icons.close,
                color: AppColors.textV2Tertiary,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
