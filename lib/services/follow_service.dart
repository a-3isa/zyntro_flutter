import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../core/models/models.dart';
import '../core/constants/constants.dart';
import '../core/auth/email_verification_gate.dart';
import '../features/auth/auth_providers.dart';
import 'notification_service.dart';

/// One page of a follower / following list, plus the cursor to continue from.
class FollowPage {
  final List<User> users;

  /// Pass back as `startAfter` to fetch the next page. Null when the list ended.
  final DocumentSnapshot<Map<String, dynamic>>? cursor;

  /// Whether another page is likely available. False once a page came back
  /// short of the requested size.
  final bool hasMore;

  const FollowPage({
    required this.users,
    this.cursor,
    required this.hasMore,
  });

  static const empty = FollowPage(users: [], hasMore: false);
}

/// Follow service for managing follow relationships.
/// Matches React Native followService.ts behavior.
class FollowService {
  final FirebaseFirestore _firestore;
  final Ref _ref;
  static const _userLookupChunkSize = 10;

  /// Rows fetched per page of a follower / following list.
  ///
  /// These queries used to be unbounded, so opening the followers list on a
  /// popular account read every follow edge that account had.
  static const followPageSize = 30;

  /// How often the follower / following count streams re-read their aggregate.
  ///
  /// Those streams used to be `.snapshots()` over the whole follow set, mapped
  /// to `docs.length` — so a user with 10,000 followers streamed 10,000
  /// documents, and re-read all of them on every single follow or unfollow. A
  /// count() aggregate bills as one read regardless of set size, but aggregates
  /// cannot be streamed, so the count is polled instead. A follower total does
  /// not need to be accurate to the second.
  static const countPollInterval = Duration(seconds: 30);

  // Simple in-memory cache for mutual follows to reduce reads
  final Map<String, List<User>> _mutualFollowsCache = {};
  DateTime? _lastMutualFetchTime;

  FollowService(this._firestore, this._ref);

  /// Generate follow document ID.
  String _getFollowId(String followerId, String followeeId) {
    return '${followerId}_$followeeId';
  }

  /// Generate block document ID used by moderation service.
  String _getBlockId(String blockerId, String blockedUserId) {
    return '${blockerId}_$blockedUserId';
  }

  /// Real friend workout invites require mutual approved follows and no blocks.
  Future<bool> canInviteToPairedSession({
    required String hostId,
    required String inviteeId,
  }) async {
    final hostFollowsInvitee = await getFollowStatus(hostId, inviteeId);
    final inviteeFollowsHost = await getFollowStatus(inviteeId, hostId);
    if (hostFollowsInvitee != FollowStatus.approved ||
        inviteeFollowsHost != FollowStatus.approved) {
      return false;
    }

    // Only check the direction the host can read (blockerId == auth.uid).
    // The reverse direction (invitee blocks host) is enforced server-side by
    // isNotBlockedPair() in Firestore security rules during session creation.
    final hostBlocksInvitee = await _firestore
        .collection('blocks')
        .doc(_getBlockId(hostId, inviteeId))
        .get();
    return !hostBlocksInvitee.exists;
  }

  /// Get the follow status between two users.
  /// Matches RN getFollowStatus.
  Future<FollowStatus?> getFollowStatus(
    String followerId,
    String followeeId,
  ) async {
    final doc = await _firestore
        .collection('follows')
        .doc(_getFollowId(followerId, followeeId))
        .get();

    if (!doc.exists) return null;
    return FollowStatus.fromString(doc.data()?['status'] ?? 'pending');
  }

  Stream<FollowStatus?> watchFollowStatus(
    String followerId,
    String followeeId,
  ) {
    return _firestore
        .collection('follows')
        .doc(_getFollowId(followerId, followeeId))
        .snapshots()
        .map(
          (doc) => doc.exists
              ? FollowStatus.fromString(doc.data()?['status'] ?? 'pending')
              : null,
        );
  }

  /// Follow a user.
  /// Matches RN followUser - creates pending for private accounts.
  Future<void> followUser({
    required String followerId,
    required String followeeId,
    required bool isPrivate,
    String? followerName,
  }) async {
    ensureEmailVerifiedForSocial(_ref.read(authSessionProvider).value);
    final followId = _getFollowId(followerId, followeeId);
    final status = isPrivate ? FollowStatus.pending : FollowStatus.approved;

    await _firestore.collection('follows').doc(followId).set({
      'followerId': followerId,
      'followeeId': followeeId,
      'status': status.value,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Send notification to followee
    if (isPrivate && followerName != null) {
      // For private accounts, notify of REQUEST
      await _ref
          .read(notificationServiceProvider)
          .notifyFollowRequest(
            recipientId: followeeId,
            requesterId: followerId,
            requesterName: followerName,
          );
    } else if (!isPrivate && followerName != null) {
      await _ref
          .read(notificationServiceProvider)
          .notifyNewFollower(
            recipientId: followeeId,
            followerId: followerId,
            followerName: followerName,
          );
    }
  }

  /// Batch follow multiple users.
  Future<void> followMultipleUsers({
    required String followerId,
    required List<String> followeeIds,
    String? followerName,
  }) async {
    ensureEmailVerifiedForSocial(_ref.read(authSessionProvider).value);
    final batch = _firestore.batch();

    for (final followeeId in followeeIds) {
      // We need to know if private (expensive to fetch individually).
      // Optimization: Assume public or handle on backend function?
      // For now, fetch user to check privacy.
      final userDoc = await _firestore
          .collection('users')
          .doc(followeeId)
          .get();
      if (!userDoc.exists) continue;

      final isPrivate = userDoc.data()?['isPrivate'] ?? false;
      final followId = _getFollowId(followerId, followeeId);
      final status = isPrivate
          ? FollowStatus.pending
          : FollowStatus
                .approved; // Wait, followStatus enum defined in models? Yes.

      batch.set(_firestore.collection('follows').doc(followId), {
        'followerId': followerId,
        'followeeId': followeeId,
        'status': status.value,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Notifications can't be batched easily in client SDK, might skip or do best effort
      // Ideally Cloud Function triggers notification on create.
    }

    await batch.commit();
  }

  /// Unfollow a user.
  /// Matches RN unfollowUser.
  Future<void> unfollowUser(String followerId, String followeeId) async {
    await _firestore
        .collection('follows')
        .doc(_getFollowId(followerId, followeeId))
        .delete();
  }

  Future<void> acceptFollowRequest(
    String followerId,
    String followeeId, {
    String? acceptorName,
  }) async {
    await _firestore
        .collection('follows')
        .doc(_getFollowId(followerId, followeeId))
        .update({
          'status': FollowStatus.approved.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });

    // Send notification to the requester that their request was accepted
    if (acceptorName != null) {
      await _ref
          .read(notificationServiceProvider)
          .notifyFollowAccepted(
            recipientId: followerId,
            acceptorId: followeeId,
            acceptorName: acceptorName,
          );
    }
  }

  /// Withdraw a sent follow request.
  /// Deletes the follow doc and marks the recipient's notification as withdrawn.
  Future<void> withdrawFollowRequest(
    String requesterId,
    String recipientId,
  ) async {
    await _firestore
        .collection('follows')
        .doc(_getFollowId(requesterId, recipientId))
        .delete();

    final notifSnap = await _firestore
        .collection('users')
        .doc(recipientId)
        .collection('notifications')
        .where('type', isEqualTo: 'followRequest')
        .where('data.fromUserId', isEqualTo: requesterId)
        .limit(1)
        .get();

    if (notifSnap.docs.isNotEmpty) {
      final notifDoc = notifSnap.docs.first;
      final existing = Map<String, dynamic>.from(
        notifDoc.data()['data'] as Map? ?? {},
      );
      existing['status'] = 'withdrawn';
      existing['actionTaken'] = 'withdrawn';
      await notifDoc.reference.update({'data': existing});
    }
  }

  /// Decline a follow request.
  /// Matches RN declineFollowRequest.
  Future<void> declineFollowRequest(
    String followerId,
    String followeeId,
  ) async {
    await _firestore
        .collection('follows')
        .doc(_getFollowId(followerId, followeeId))
        .delete();
  }

  Future<List<User>> _fetchUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final uniqueIds = userIds.toSet().toList(growable: false);
    final usersById = <String, User>{};

    for (var i = 0; i < uniqueIds.length; i += _userLookupChunkSize) {
      final chunk = uniqueIds.sublist(
        i,
        (i + _userLookupChunkSize).clamp(0, uniqueIds.length),
      );
      final docs = await Future.wait(
        chunk.map((id) => _firestore.collection('users').doc(id).get()),
      );

      for (final doc in docs) {
        if (doc.exists) {
          usersById[doc.id] = User.fromFirestore(doc);
        }
      }
    }

    return userIds
        .map((id) => usersById[id])
        .whereType<User>()
        .toList(growable: false);
  }

  /// Get pending follow requests for a user.
  /// Matches RN getPendingFollowRequests.
  Future<List<User>> getPendingFollowRequests(
    String userId, {
    int limit = followPageSize,
  }) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followeeId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .limit(limit)
        .get();

    final followerIds = snapshot.docs
        .map((doc) => doc.data()['followerId'] as String)
        .toList();

    if (followerIds.isEmpty) return [];
    return _fetchUsersByIds(followerIds);
  }

  /// One page of approved follow edges, resolved to user profiles.
  ///
  /// [matchField] is the side of the edge being matched against [userId], and
  /// [readField] is the side to resolve into profiles.
  Future<FollowPage> _followPage({
    required String userId,
    required String matchField,
    required String readField,
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    var query = _firestore
        .collection('follows')
        .where(matchField, isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        // A stable order is what makes the cursor meaningful; without it two
        // pages can overlap or skip rows.
        .orderBy(FieldPath.documentId)
        .limit(limit);

    if (startAfter != null) query = query.startAfterDocument(startAfter);

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return FollowPage.empty;

    final ids = snapshot.docs
        .map((doc) => doc.data()[readField] as String)
        .toList();

    return FollowPage(
      users: await _fetchUsersByIds(ids),
      cursor: snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  /// One page of a user's followers, newest cursor first.
  Future<FollowPage> getFollowersPage(
    String userId, {
    int limit = followPageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    return _followPage(
      userId: userId,
      matchField: 'followeeId',
      readField: 'followerId',
      limit: limit,
      startAfter: startAfter,
    );
  }

  /// One page of the accounts a user follows.
  Future<FollowPage> getFollowingPage(
    String userId, {
    int limit = followPageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    return _followPage(
      userId: userId,
      matchField: 'followerId',
      readField: 'followeeId',
      limit: limit,
      startAfter: startAfter,
    );
  }

  /// Get followers list for a user.
  ///
  /// Returns the first page only. Callers that need to scroll past it should
  /// use [getFollowersPage], which hands back a cursor.
  Future<List<User>> getFollowersList(String userId) async {
    return (await getFollowersPage(userId)).users;
  }

  /// Get following list for a user.
  ///
  /// Returns the first page only — see [getFollowingPage] to continue.
  Future<List<User>> getFollowingList(String userId) async {
    return (await getFollowingPage(userId)).users;
  }

  /// Get list of IDs that the user follows.
  /// Ceiling on how many follow edges are read at once for the id list.
  ///
  /// Deliberately far above a realistic following count rather than a display
  /// page: this list decides whose posts appear in the feed and who is excluded
  /// from suggestions, so quietly truncating it would silently change what a
  /// user sees. The cap bounds worst-case cost, and reaching it is logged
  /// rather than passed over.
  static const followingIdsLimit = 1000;

  Future<List<String>> getFollowingIds(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .limit(followingIdsLimit)
        .get();

    if (snapshot.docs.length == followingIdsLimit) {
      debugPrint(
        '[FollowService] $userId follows at least $followingIdsLimit accounts; '
        'the feed and suggestion filters are now truncated and need paging.',
      );
    }

    return snapshot.docs
        .map((doc) => doc.data()['followeeId'] as String)
        .toList();
  }

  /// Get followers count.
  Future<int> getFollowersCount(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followeeId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .count() // Use aggregations if available in plugin, else get().
        .get();

    return snapshot.count ?? 0;
  }

  /// Emits [count] immediately, then re-reads it every [countPollInterval].
  ///
  /// Polling an aggregate rather than streaming the underlying documents: one
  /// read per poll instead of one per follow edge per change.
  Stream<int> _pollCount(Future<int> Function() count) async* {
    yield await count();
    yield* Stream.periodic(countPollInterval).asyncMap((_) => count());
  }

  Stream<int> watchFollowersCount(String userId) {
    return _pollCount(() => getFollowersCount(userId));
  }

  /// Get following count.
  Future<int> getFollowingCount(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  Stream<int> watchFollowingCount(String userId) {
    return _pollCount(() => getFollowingCount(userId));
  }

  /// Get mutual follows (friends) for a user.
  /// Matches RN getMutualFollows.
  Future<List<User>> getMutualFollows(String userId) async {
    // Check cache (15 min validity)
    if (_mutualFollowsCache.containsKey(userId) &&
        _lastMutualFetchTime != null &&
        DateTime.now().difference(_lastMutualFetchTime!) <
            const Duration(minutes: 15)) {
      return _mutualFollowsCache[userId]!;
    }

    // Get users this person follows
    final following = await getFollowingList(userId);
    final followingIds = following.map((u) => u.id).toSet();

    // Get users following this person
    final followers = await getFollowersList(userId);

    // Return intersection
    final mutuals = followers
        .where((u) => followingIds.contains(u.id))
        .toList();

    // Update cache
    _mutualFollowsCache[userId] = mutuals;
    _lastMutualFetchTime = DateTime.now();

    return mutuals;
  }

  /// Get suggested users to follow.
  /// Simple implementation: Fetch recent users who are not me and not already followed.
  Future<List<User>> getSuggestedUsers(
    String currentUserId, {
    int limit = 10,
  }) async {
    try {
      final followingIds = await getFollowingIds(currentUserId);
      final allExcludedIds = {...followingIds, currentUserId};

      // Fetch recent public users only (Z-SEC-001 list ACL).
      final snapshot = await _firestore
          .collection('users')
          .where('isPrivate', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit * 2) // Fetch more to allow for client-side filtering
          .get();

      final users = snapshot.docs
          .map((doc) => User.fromFirestore(doc))
          .where((user) => !allExcludedIds.contains(user.id))
          .take(limit)
          .toList();

      return users;
    } catch (e) {
      debugPrint('[FollowService] Error getting suggestions: $e');
      return [];
    }
  }
}

/// Follow service provider.
final followServiceProvider = Provider<FollowService>((ref) {
  return FollowService(ref.watch(authFirestoreProvider), ref);
});

/// Pending follow requests count provider.
final pendingFollowRequestsCountProvider = FutureProvider<int>((ref) async {
  final authState = ref.watch(authSessionProvider);
  final uid = authState.value?.id;
  if (uid == null) return 0;

  final requests = await ref
      .watch(followServiceProvider)
      .getPendingFollowRequests(uid);
  return requests.length;
});
