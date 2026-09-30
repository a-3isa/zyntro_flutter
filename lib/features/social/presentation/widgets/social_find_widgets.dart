import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/facebook_friends_provider.dart';

/// "People you may know" block for the Find tab (Z-ARCH-002).
class SocialPeopleYouMayKnow extends ConsumerWidget {
  const SocialPeopleYouMayKnow({
    super.key,
    required this.followedIds,
    required this.onFollow,
  });

  final Set<String> followedIds;
  final ValueChanged<String> onFollow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(facebookFriendsProvider);

    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PEOPLE YOU MAY KNOW',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  fontSize: 10,
                  color: AppColors.textV2Tertiary,
                ),
              ),
              const SizedBox(height: 8),
              ...friends.take(10).map(
                (user) => SocialFacebookFriendRow(
                  displayName: user.displayName,
                  photoUrl: user.photoUrl,
                  isFollowed: followedIds.contains(user.id),
                  onFollow: () => onFollow(user.id),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}

/// Compact follow row for a Facebook-matched friend (Z-ARCH-002).
class SocialFacebookFriendRow extends StatelessWidget {
  const SocialFacebookFriendRow({
    super.key,
    required this.displayName,
    required this.photoUrl,
    required this.isFollowed,
    required this.onFollow,
  });

  final String displayName;
  final String? photoUrl;
  final bool isFollowed;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.surfaceV2Active,
          backgroundImage: photoUrl != null
              ? CachedNetworkImageProvider(photoUrl!)
              : null,
          child: photoUrl == null
              ? Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.signal,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        title: Text(
          displayName,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textV2Primary,
            fontSize: 14,
          ),
        ),
        trailing: isFollowed
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceV2Active,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Following',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textV2Tertiary,
                  ),
                ),
              )
            : GestureDetector(
                onTap: onFollow,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.signal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Follow',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
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
