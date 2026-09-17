import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/workout_type_visuals.dart';
import '../../../../services/post_service.dart';
import '../profile_providers.dart';
import 'profile_empty_states.dart';

/// Profile posts grid tab (Z-ARCH-002).
class ProfilePostsTab extends ConsumerWidget {
  const ProfilePostsTab({
    super.key,
    required this.targetUserId,
    required this.isCurrentUser,
    required this.isPrivate,
  });

  final String targetUserId;
  final bool isCurrentUser;
  final bool isPrivate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isCurrentUser && isPrivate) {
      final followStatusAsync = ref.watch(followStatusProvider(targetUserId));
      final isFollowing = followStatusAsync.value == FollowStatus.approved;
      if (!isFollowing) return const ProfilePrivateLocked();
    }

    final postsAsync = ref.watch(userPostsProvider(targetUserId));

    return postsAsync.when(
      data: (allPosts) {
        final posts = isCurrentUser
            ? allPosts
            : allPosts.where((p) => p.visibility != 'private').toList();
        if (posts.isEmpty) return const ProfileEmptyPosts();

        return GridView.builder(
          padding: const EdgeInsets.all(3),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
            childAspectRatio: 1,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final firstMedia = post.mediaURLs?.isNotEmpty == true
                ? post.mediaURLs!.first
                : null;

            if (firstMedia != null && firstMedia.isNotEmpty) {
              return GestureDetector(
                onTap: () => context.push('/post/${post.id}'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: firstMedia,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(color: AppColors.surfaceV2),
                    errorWidget: (_, _, _) => Container(
                      color: AppColors.surfaceV2,
                      child: const Icon(
                        Icons.broken_image,
                        color: AppColors.textV2Tertiary,
                      ),
                    ),
                  ),
                ),
              );
            }

            final type = post.type;
            final typeColor = AppColors.typeColor(type.toLowerCase());
            final typeIcon = workoutTypeIcon(type);
            final setsCount = post.summary.totalSets ?? 0;

            return GestureDetector(
              onTap: () => context.push('/post/${post.id}'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.0,
                          colors: [
                            typeColor.withValues(alpha: 0.094),
                            AppColors.surfaceV2,
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        typeIcon,
                        size: MediaQuery.of(context).size.width / 3 * 0.7,
                        color: typeColor.withValues(alpha: 0.12),
                      ),
                    ),
                    if (setsCount > 0)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Text(
                          '${setsCount}s',
                          style: AppTextStyles.h5.copyWith(
                            fontSize: 9,
                            color: AppColors.textV2Primary,
                          ),
                        ),
                      ),
                    if (post.visibility == 'private')
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundV2.withValues(
                              alpha: 0.6,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock,
                            size: 11,
                            color: AppColors.textV2Secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.signal,
        ),
      ),
      error: (_, _) => const SizedBox(),
    );
  }
}
