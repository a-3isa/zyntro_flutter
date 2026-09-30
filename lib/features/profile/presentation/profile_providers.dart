import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/constants.dart';
import '../../../core/models/models.dart';
import '../../../services/follow_service.dart';
import '../../../services/session_service.dart';
import '../../auth/auth_providers.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

// These providers are all scoped to a profile screen, and every one of them
// holds a live Firestore listener. Without autoDispose they outlive the screen
// for the rest of the app session, so visiting N profiles left 5N listeners
// running — each still billing for every write to the data it watched.

/// Provider to fetch another user's profile by ID.
final otherUserProfileProvider = StreamProvider.autoDispose.family<User?, String>((
  ref,
  userId,
) {
  return ref
      .watch(authFirestoreProvider)
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) => doc.exists ? User.fromFirestore(doc) : null);
});

final currentUserProfileProvider = StreamProvider.autoDispose<User?>((ref) {
  final uid = ref.watch(authSessionProvider).value?.id;
  if (uid == null) return Stream.value(null);
  return ref
      .watch(authFirestoreProvider)
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? User.fromFirestore(doc) : null);
});

/// Provider for followers count.
final followersCountProvider = StreamProvider.autoDispose.family<int, String>((
  ref,
  userId,
) {
  return ref.watch(followServiceProvider).watchFollowersCount(userId);
});

/// Provider for following count.
final followingCountProvider = StreamProvider.autoDispose.family<int, String>((
  ref,
  userId,
) {
  return ref.watch(followServiceProvider).watchFollowingCount(userId);
});

/// Provider for follow status between current user and target user.
final followStatusProvider = StreamProvider.autoDispose.family<FollowStatus?, String>((
  ref,
  targetUserId,
) {
  final authState = ref.watch(authSessionProvider);
  final currentUserId = authState.value?.id;
  if (currentUserId == null || currentUserId == targetUserId) {
    return Stream.value(null);
  }
  return ref
      .watch(followServiceProvider)
      .watchFollowStatus(currentUserId, targetUserId);
});

/// Whether the target user follows the currently signed-in user back.
final targetFollowsCurrentProvider = StreamProvider.autoDispose.family<bool, String>((
  ref,
  targetUserId,
) {
  final currentUserId = ref.watch(authSessionProvider).value?.id;
  if (currentUserId == null || currentUserId == targetUserId) {
    return Stream.value(false);
  }
  return ref
      .watch(followServiceProvider)
      .watchFollowStatus(targetUserId, currentUserId)
      .map((status) => status == FollowStatus.approved);
});

/// Provider for a user's recent sessions (up to 100).
final userSessionsProvider = StreamProvider.autoDispose.family<List<Session>, String>((
  ref,
  userId,
) {
  return ref
      .watch(sessionServiceProvider)
      .watchUserSessions(userId, limit: 100);
});
