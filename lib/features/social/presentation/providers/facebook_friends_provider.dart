import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/auth_providers.dart';
import '../../../../features/auth/domain/entities/user_profile_entity.dart';
import '../../../../services/facebook_link_service.dart';
import '../../../../services/follow_service.dart';

/// Drop self and already-followed users from Facebook friend suggestions.
List<UserProfileEntity> filterUnfollowedFacebookFriends({
  required List<UserProfileEntity> friends,
  required Set<String> followingIds,
  required String selfId,
}) {
  final exclude = {...followingIds, selfId};
  return friends.where((u) => !exclude.contains(u.id)).toList();
}

/// Fetches Facebook friends who are on Zyntro, filtered to exclude
/// users the current user already follows.
///
/// Returns an empty list if the current user has no facebookUid set.
final facebookFriendsProvider =
    FutureProvider.autoDispose<List<UserProfileEntity>>((ref) async {
  final profile = await ref.watch(authUserProfileProvider.future);
  if (profile == null || !profile.isFacebookConnected) return [];

  final fbService = ref.read(facebookLinkServiceProvider);
  final followService = ref.read(followServiceProvider);

  final friends = await fbService.fetchFriendsOnApp();
  if (friends.isEmpty) return [];

  final followingIds = await followService.getFollowingIds(profile.id);

  return filterUnfollowedFacebookFriends(
    friends: friends,
    followingIds: followingIds.toSet(),
    selfId: profile.id,
  );
});
