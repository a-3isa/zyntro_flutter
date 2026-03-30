import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/models.dart';
import '../features/auth/auth_providers.dart';
import 'user_service.dart';

/// Moderation service for report/block/ban functionality.
/// Handles user reports, blocks, and admin moderation actions.
class ModerationService {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  ModerationService(this._firestore, this._ref);

  // ============================================================
  // Report Methods
  // ============================================================

  /// Report a user.
  Future<void> reportUser({
    required String reporterId,
    required String reportedUserId,
    required ReportReason reason,
    String? description,
  }) async {
    final report = Report(
      id: '',
      reporterId: reporterId,
      reportedUserId: reportedUserId,
      reason: reason,
      description: description,
      status: ReportStatus.pending,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('reports').add(report.toFirestore());
    debugPrint('[ModerationService] User reported: $reportedUserId');
  }

  /// Report a post.
  Future<void> reportPost({
    required String reporterId,
    required String postId,
    required String postAuthorId,
    required ReportReason reason,
    String? description,
  }) async {
    await _firestore.collection('reports').add({
      'reporterId': reporterId,
      'reportedUserId': postAuthorId,
      'reportedPostId': postId,
      'reason': reason.value,
      if (description != null) 'description': description,
      'status': ReportStatus.pending.value,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[ModerationService] Post reported: $postId');
  }

  /// Report a comment.
  Future<void> reportComment({
    required String reporterId,
    required String commentId,
    required String commentAuthorId,
    required ReportReason reason,
    String? description,
  }) async {
    await _firestore.collection('reports').add({
      'reporterId': reporterId,
      'reportedUserId': commentAuthorId,
      'reportedCommentId': commentId,
      'reason': reason.value,
      if (description != null) 'description': description,
      'status': ReportStatus.pending.value,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[ModerationService] Comment reported: $commentId');
  }

  /// Get reports submitted by a user.
  Future<List<Report>> getMyReports(String userId) async {
    final snapshot = await _firestore
        .collection('reports')
        .where('reporterId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => Report.fromFirestore(doc)).toList();
  }

  // ============================================================
  // Block Methods
  // ============================================================

  /// Generate block document ID.
  String _getBlockId(String blockerId, String blockedUserId) {
    return '${blockerId}_$blockedUserId';
  }

  /// Block a user.
  Future<void> blockUser(String blockerId, String blockedUserId) async {
    final blockId = _getBlockId(blockerId, blockedUserId);

    await _firestore.collection('blocks').doc(blockId).set({
      'blockerId': blockerId,
      'blockedUserId': blockedUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Remove from buddies if applicable
    try {
      await _ref.read(userServiceProvider).computeAndCacheBuddies(blockerId);
    } catch (e) {
      debugPrint(
        '[ModerationService] Error recomputing buddies after block: $e',
      );
    }

    debugPrint('[ModerationService] User blocked: $blockedUserId');
  }

  /// Unblock a user.
  Future<void> unblockUser(String blockerId, String blockedUserId) async {
    final blockId = _getBlockId(blockerId, blockedUserId);
    await _firestore.collection('blocks').doc(blockId).delete();
    debugPrint('[ModerationService] User unblocked: $blockedUserId');
  }

  /// Get list of blocked users.
  Future<List<User>> getBlockedUsers(String userId) async {
    final snapshot = await _firestore
        .collection('blocks')
        .where('blockerId', isEqualTo: userId)
        .get();

    final blockedUserIds = snapshot.docs
        .map((doc) => doc.data()['blockedUserId'] as String)
        .toList();

    if (blockedUserIds.isEmpty) return [];

    // Fetch user profiles
    final users = <User>[];
    for (final id in blockedUserIds) {
      final userDoc = await _firestore.collection('users').doc(id).get();
      if (userDoc.exists) {
        users.add(User.fromFirestore(userDoc));
      }
    }
    return users;
  }

  /// Get list of blocked user IDs (for filtering).
  Future<List<String>> getBlockedUserIds(String userId) async {
    final snapshot = await _firestore
        .collection('blocks')
        .where('blockerId', isEqualTo: userId)
        .get();

    return snapshot.docs
        .map((doc) => doc.data()['blockedUserId'] as String)
        .toList();
  }

  /// Check if a user is blocked.
  Future<bool> isUserBlocked(String blockerId, String blockedUserId) async {
    final blockId = _getBlockId(blockerId, blockedUserId);
    final doc = await _firestore.collection('blocks').doc(blockId).get();
    return doc.exists;
  }

  // ============================================================
  // Moderation Methods (Admin only)
  // ============================================================

  /// Get pending reports (for moderators).
  Future<List<Report>> getPendingReports() async {
    final snapshot = await _firestore
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => Report.fromFirestore(doc)).toList();
  }

  /// Review a report (for moderators).
  Future<void> reviewReport({
    required String reportId,
    required ReportStatus newStatus,
    required String moderatorId,
  }) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': newStatus.value,
      'reviewedBy': moderatorId,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    debugPrint(
      '[ModerationService] Report reviewed: $reportId -> ${newStatus.value}',
    );
  }

  /// Ban a user (for moderators).
  Future<void> banUser({
    required String userId,
    required String reason,
    Duration? duration,
    required String moderatorId,
  }) async {
    final bannedUntil = duration != null
        ? DateTime.now().add(duration)
        : null; // null = permanent ban

    await _firestore.collection('users').doc(userId).update({
      'isBanned': true,
      'banReason': reason,
      if (bannedUntil != null) 'bannedUntil': Timestamp.fromDate(bannedUntil),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
      '[ModerationService] User banned: $userId (${duration ?? "permanent"})',
    );
  }

  /// Unban a user (for moderators).
  Future<void> unbanUser(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'isBanned': false,
      'banReason': FieldValue.delete(),
      'bannedUntil': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[ModerationService] User unbanned: $userId');
  }

  /// Check if current user is a moderator.
  Future<bool> isModerator(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return false;
    return doc.data()?['isModerator'] == true;
  }
}

/// Moderation service provider.
final moderationServiceProvider = Provider<ModerationService>((ref) {
  return ModerationService(ref.watch(authFirestoreProvider), ref);
});

/// Blocked user IDs provider.
final blockedUserIdsProvider = FutureProvider<List<String>>((ref) async {
  final authState = ref.watch(authSessionProvider);
  final uid = authState.valueOrNull?.id;
  if (uid == null) return [];

  return ref.watch(moderationServiceProvider).getBlockedUserIds(uid);
});

/// Blocked users list provider.
final blockedUsersProvider = FutureProvider<List<User>>((ref) async {
  final authState = ref.watch(authSessionProvider);
  final uid = authState.valueOrNull?.id;
  if (uid == null) return [];

  return ref.watch(moderationServiceProvider).getBlockedUsers(uid);
});

/// Pending reports provider (for moderators).
final pendingReportsProvider = FutureProvider<List<Report>>((ref) async {
  return ref.watch(moderationServiceProvider).getPendingReports();
});

