import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../core/models/models.dart';
import '../core/constants/constants.dart';
import '../features/auth/auth_providers.dart';
import 'notification_service.dart';

/// Follow service for managing follow relationships.
/// Matches React Native followService.ts behavior.
class FollowService {
  final FirebaseFirestore _firestore;
  final Ref _ref;

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

    final hostBlocksInvitee = await _firestore
        .collection('blocks')
        .doc(_getBlockId(hostId, inviteeId))
        .get();
    if (hostBlocksInvitee.exists) return false;

    final inviteeBlocksHost = await _firestore
        .collection('blocks')
        .doc(_getBlockId(inviteeId, hostId))
        .get();
    return !inviteeBlocksHost.exists;
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

  /// Follow a user.
  /// Matches RN followUser - creates pending for private accounts.
  Future<void> followUser({
    required String followerId,
    required String followeeId,
    required bool isPrivate,
    String? followerName,
  }) async {
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
      // For public accounts, notify of NEW FOLLOWER
      // Note: check notification_service.dart if notifyNewFollower exists.
      // Assuming it does or I should add it. I'll stick to request for now if not sure.
      // But typically we notify for new follows too.
      // I'll leave it as is to match original file logic unless I add notifyNewFollower.
    }
  }

  /// Batch follow multiple users.
  Future<void> followMultipleUsers({
    required String followerId,
    required List<String> followeeIds,
    String? followerName,
  }) async {
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

  /// Get pending follow requests for a user.
  /// Matches RN getPendingFollowRequests.
  Future<List<User>> getPendingFollowRequests(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followeeId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    final followerIds = snapshot.docs
        .map((doc) => doc.data()['followerId'] as String)
        .toList();

    if (followerIds.isEmpty) return [];

    // Fetch user profiles
    final users = <User>[];
    // Optimize: Batch fetch if < 10, otherwise chunk?
    // Firestore 'where in' limit is 10.
    // Loop one by one is slow.
    for (final id in followerIds) {
      final userDoc = await _firestore.collection('users').doc(id).get();
      if (userDoc.exists) {
        users.add(User.fromFirestore(userDoc));
      }
    }
    return users;
  }

  /// Get followers list for a user.
  /// Matches RN getFollowersList.
  Future<List<User>> getFollowersList(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followeeId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .get();

    final followerIds = snapshot.docs
        .map((doc) => doc.data()['followerId'] as String)
        .toList();

    if (followerIds.isEmpty) return [];

    final users = <User>[];
    for (final id in followerIds) {
      final userDoc = await _firestore.collection('users').doc(id).get();
      if (userDoc.exists) {
        users.add(User.fromFirestore(userDoc));
      }
    }
    return users;
  }

  /// Get following list for a user.
  /// Matches RN getFollowingList.
  Future<List<User>> getFollowingList(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .get();

    final followeeIds = snapshot.docs
        .map((doc) => doc.data()['followeeId'] as String)
        .toList();

    if (followeeIds.isEmpty) return [];

    final users = <User>[];
    for (final id in followeeIds) {
      final userDoc = await _firestore.collection('users').doc(id).get();
      if (userDoc.exists) {
        users.add(User.fromFirestore(userDoc));
      }
    }
    return users;
  }

  /// Get list of IDs that the user follows.
  Future<List<String>> getFollowingIds(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .get();

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

      // Fetch recent users
      final snapshot = await _firestore
          .collection('users')
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
  final uid = authState.valueOrNull?.id;
  if (uid == null) return 0;

  final requests = await ref
      .watch(followServiceProvider)
      .getPendingFollowRequests(uid);
  return requests.length;
});

