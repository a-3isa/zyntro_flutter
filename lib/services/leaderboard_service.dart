import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';
import 'follow_service.dart';

/// Leaderboard entry for display.
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final String? photoURL;
  final int score;
  final int streak;
  final int rank;
  final bool isCurrentUser;

  LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.photoURL,
    required this.score,
    this.streak = 0,
    required this.rank,
    this.isCurrentUser = false,
  });
}

/// Event model for community events.
class LeaderboardEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final int participantCount;
  final String? imageUrl;

  LeaderboardEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.participantCount,
    this.imageUrl,
  });

  factory LeaderboardEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaderboardEvent(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participantCount: data['participantCount'] ?? 0,
      imageUrl: data['imageUrl'],
    );
  }
}

/// Leaderboard service for friends/global rankings.
/// Matches React Native leaderboardService.ts behavior.
class LeaderboardService {
  final FirebaseFirestore _firestore;

  LeaderboardService(this._firestore);

  /// Get friends leaderboard based on mutual follows.
  /// Matches RN getFriendsLeaderboard.
  /// Sorts by streak descending, then by workoutScore descending.
  Future<List<LeaderboardEntry>> getFriendsLeaderboard(
    String currentUserId,
    List<String> followingIds,
  ) async {
    try {
      final userIds = [...followingIds, currentUserId];
      final List<LeaderboardEntry> entries = [];

      // Firestore 'whereIn' has a limit of 10 items, so chunk the queries
      const chunkSize = 10;
      for (var i = 0; i < userIds.length; i += chunkSize) {
        final chunk = userIds.skip(i).take(chunkSize).toList();
        final querySnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in querySnapshot.docs) {
          final data = doc.data();

          // Fetch streak from user's stats subcollection
          int streak = 0;
          try {
            final statsDoc = await _firestore
                .collection('users')
                .doc(doc.id)
                .collection('stats')
                .doc('current')
                .get();
            if (statsDoc.exists) {
              streak = statsDoc.data()?['currentStreak'] ?? 0;
            }
          } catch (e) {
            debugPrint('Error fetching streak for ${doc.id}: $e');
          }

          entries.add(
            LeaderboardEntry(
              userId: doc.id,
              displayName: data['displayName'] ?? 'Unknown',
              photoURL: data['photoURL'],
              score: data['workoutScore'] ?? 0,
              streak: streak,
              rank: 0, // Will be assigned after sorting
              isCurrentUser: doc.id == currentUserId,
            ),
          );
        }
      }

      // Sort by streak descending first, then by score descending
      entries.sort((a, b) {
        final streakCompare = b.streak.compareTo(a.streak);
        if (streakCompare != 0) return streakCompare;
        return b.score.compareTo(a.score);
      });

      // Assign ranks after sorting
      for (var i = 0; i < entries.length; i++) {
        entries[i] = LeaderboardEntry(
          userId: entries[i].userId,
          displayName: entries[i].displayName,
          photoURL: entries[i].photoURL,
          score: entries[i].score,
          streak: entries[i].streak,
          rank: i + 1,
          isCurrentUser: entries[i].isCurrentUser,
        );
      }

      return entries;
    } catch (e) {
      debugPrint('Error getting friends leaderboard: $e');
      return [];
    }
  }

  /// Get global leaderboard (top 50 users by workoutScore).
  /// Matches RN getGlobalLeaderboard.
  Future<List<LeaderboardEntry>> getGlobalLeaderboard(
    String currentUserId, {
    int limit = 50,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('workoutScore', descending: true)
          .limit(limit)
          .get();

      final entries = <LeaderboardEntry>[];
      var rank = 1;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        entries.add(
          LeaderboardEntry(
            userId: doc.id,
            displayName: data['displayName'] ?? 'Unknown',
            photoURL: data['photoURL'],
            score: data['workoutScore'] ?? 0,
            rank: rank++,
            isCurrentUser: doc.id == currentUserId,
          ),
        );
      }

      return entries;
    } catch (e) {
      debugPrint('Error getting global leaderboard: $e');
      return [];
    }
  }

  /// Check if user has global leaderboard access.
  Future<bool> hasGlobalLeaderboardAccess(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      return doc.data()?['hasGlobalLeaderboardAccess'] ?? false;
    } catch (e) {
      debugPrint('Error checking global leaderboard access: $e');
      return false;
    }
  }

  /// Grant global leaderboard access to a user.
  Future<void> grantGlobalLeaderboardAccess(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'hasGlobalLeaderboardAccess': true,
        'globalAccessGrantedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error granting global leaderboard access: $e');
      rethrow;
    }
  }

  /// Get community events.
  /// Returns events from Firestore or fallback mock events.
  Future<List<LeaderboardEvent>> getEvents() async {
    try {
      final querySnapshot = await _firestore
          .collection('events')
          .orderBy('date')
          .limit(10)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // Return mock events for demo
        return _getMockEvents();
      }

      return querySnapshot.docs
          .map((doc) => LeaderboardEvent.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting events: $e');
      return _getMockEvents();
    }
  }

  /// Join an event.
  Future<void> joinEvent(String eventId, String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('joinedEvents')
          .doc(eventId)
          .set({'joinedAt': FieldValue.serverTimestamp()});

      // Increment participant count
      await _firestore.collection('events').doc(eventId).update({
        'participantCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error joining event: $e');
      rethrow;
    }
  }

  /// Check if user has joined an event.
  Future<bool> hasJoinedEvent(String eventId, String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('joinedEvents')
          .doc(eventId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking joined event: $e');
      return false;
    }
  }

  /// Mock events for demo/fallback.
  List<LeaderboardEvent> _getMockEvents() {
    final now = DateTime.now();
    return [
      LeaderboardEvent(
        id: 'mock_1',
        title: 'Global Virtual 5K',
        description: 'Join runners worldwide for a virtual 5K challenge!',
        date: now.add(const Duration(days: 7)),
        participantCount: 1234,
        imageUrl: null,
      ),
      LeaderboardEvent(
        id: 'mock_2',
        title: 'Strength Summit',
        description: 'Test your limits in our monthly strength challenge.',
        date: now.add(const Duration(days: 14)),
        participantCount: 567,
        imageUrl: null,
      ),
      LeaderboardEvent(
        id: 'mock_3',
        title: 'Yoga Flow Challenge',
        description: '30 days of yoga for flexibility and mindfulness.',
        date: now.add(const Duration(days: 21)),
        participantCount: 890,
        imageUrl: null,
      ),
    ];
  }
}

/// Leaderboard service provider.
final leaderboardServiceProvider = Provider<LeaderboardService>((ref) {
  return LeaderboardService(ref.watch(firestoreProvider));
});

/// Friends leaderboard provider.
final friendsLeaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, String>((ref, userId) async {
      final leaderboardService = ref.watch(leaderboardServiceProvider);
      final followService = ref.watch(followServiceProvider);

      // Get users that the current user follows
      final following = await followService.getFollowingList(userId);
      final followingIds = following.map((u) => u.id).toList();

      return leaderboardService.getFriendsLeaderboard(userId, followingIds);
    });

/// Global leaderboard provider.
final globalLeaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, String>((ref, userId) async {
      final leaderboardService = ref.watch(leaderboardServiceProvider);
      return leaderboardService.getGlobalLeaderboard(userId);
    });

/// Global leaderboard access provider.
final hasGlobalAccessProvider = FutureProvider.family<bool, String>((
  ref,
  userId,
) async {
  final leaderboardService = ref.watch(leaderboardServiceProvider);
  return leaderboardService.hasGlobalLeaderboardAccess(userId);
});

/// Events provider.
final eventsProvider = FutureProvider<List<LeaderboardEvent>>((ref) async {
  final leaderboardService = ref.watch(leaderboardServiceProvider);
  return leaderboardService.getEvents();
});
