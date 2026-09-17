import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/models.dart';
import '../features/auth/auth_providers.dart';
import '../features/session/domain/workout_streak.dart';

/// Streak risk levels for at-risk detection.
enum StreakRisk {
  safe, // Last workout within normal window
  warning, // Last workout >20 hours ago
  critical, // Last workout >22 hours ago, streak at risk
}

/// Friend streak comparison data for leaderboard display.
class FriendStreakComparison {
  final String userId;
  final String displayName;
  final String? photoURL;
  final int currentStreak;
  final int longestStreak;
  final bool isCurrentUser;
  final int rank;
  final String? lastWorkoutDate;
  final StreakRisk riskLevel;

  FriendStreakComparison({
    required this.userId,
    required this.displayName,
    this.photoURL,
    required this.currentStreak,
    required this.longestStreak,
    required this.isCurrentUser,
    required this.rank,
    this.lastWorkoutDate,
    this.riskLevel = StreakRisk.safe,
  });
}

/// Streak milestone info.
class StreakMilestone {
  final int nextMilestone;
  final double progress;
  final int currentStreak;

  StreakMilestone({
    required this.nextMilestone,
    required this.progress,
    required this.currentStreak,
  });
}

/// User streak data.
class UserStreak {
  final int currentStreak;
  final int longestStreak;
  final String? lastWorkoutDate;
  final int totalWorkouts;
  final int weeklyWorkouts;

  /// Completed sessions that had more than one participant. Derived from the
  /// same session read the other stats come from, so badge checks can use it
  /// instead of re-scanning the user's whole session history.
  final int buddyWorkouts;

  UserStreak({
    required this.currentStreak,
    required this.longestStreak,
    this.lastWorkoutDate,
    required this.totalWorkouts,
    this.weeklyWorkouts = 0,
    this.buddyWorkouts = 0,
  });
}

/// Buddy with presence information.
class BuddyWithPresence {
  final String id;
  final String displayName;
  final String? photoURL;
  final bool isOnline;
  final DateTime? lastActive;

  BuddyWithPresence({
    required this.id,
    required this.displayName,
    this.photoURL,
    required this.isOnline,
    this.lastActive,
  });
}

/// Badge criteria types.
enum BadgeCriteriaType {
  cheersSent,
  workouts,
  streak,
  buddySessions,
  earlyBird,
  nightOwl,
}

/// Badge criteria.
class BadgeCriteria {
  final BadgeCriteriaType type;
  final int threshold;

  BadgeCriteria({required this.type, required this.threshold});
}

/// Badge model.
class Badge {
  final String id;
  final String name;
  final String icon;
  final String description;
  final BadgeCriteria criteria;
  final DateTime? unlockedAt;

  Badge({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.criteria,
    this.unlockedAt,
  });
}

/// Available badges that can be earned.
/// Matches RN AVAILABLE_BADGES.
final List<Badge> availableBadges = [
  Badge(
    id: 'supporter',
    name: 'Supporter',
    icon: '🎉',
    description: 'Send 5+ cheers in a single session',
    criteria: BadgeCriteria(type: BadgeCriteriaType.cheersSent, threshold: 5),
  ),
  Badge(
    id: 'consistent',
    name: 'Consistent',
    icon: '🔥',
    description: 'Maintain a 7-day workout streak',
    criteria: BadgeCriteria(type: BadgeCriteriaType.streak, threshold: 7),
  ),
  Badge(
    id: 'social_butterfly',
    name: 'Social Butterfly',
    icon: '🦋',
    description: 'Complete 10+ buddy sessions',
    criteria: BadgeCriteria(
      type: BadgeCriteriaType.buddySessions,
      threshold: 10,
    ),
  ),
  Badge(
    id: 'iron_will',
    name: 'Iron Will',
    icon: '🏋️',
    description: 'Complete 50+ total workouts',
    criteria: BadgeCriteria(type: BadgeCriteriaType.workouts, threshold: 50),
  ),
  Badge(
    id: 'early_bird',
    name: 'Early Bird',
    icon: '🌅',
    description: 'Complete a workout before 7am',
    criteria: BadgeCriteria(type: BadgeCriteriaType.earlyBird, threshold: 1),
  ),
  Badge(
    id: 'night_owl',
    name: 'Night Owl',
    icon: '🦉',
    description: 'Complete a workout after 10pm',
    criteria: BadgeCriteria(type: BadgeCriteriaType.nightOwl, threshold: 1),
  ),
];

/// User service for profiles, streaks, search, and badges.
/// Matches React Native userService.ts behavior.
class UserService {
  final FirebaseFirestore _firestore;

  UserService(this._firestore);

  static const int onlineThresholdMs = 5 * 60 * 1000; // 5 minutes
  final Map<String, ({UserStreak streak, DateTime fetchedAt})> _streakCache =
      {};

  /// Read a user's workout streak stats.
  ///
  /// Served from the counters maintained on the user document at session end,
  /// which costs one document read regardless of how long the user's history
  /// is. Users whose documents predate those counters fall back to
  /// [_calculateUserStreakFromHistory], which scans their sessions — that path
  /// exists only until a user's next completed session writes the counters, or
  /// until the backfill in scripts/backfill_user_streak_counters.js runs.
  Future<UserStreak> calculateUserStreak(String userId) async {
    // Check cache (5 min TTL)
    if (_streakCache.containsKey(userId)) {
      final cached = _streakCache[userId]!;
      if (DateTime.now().difference(cached.fetchedAt).inMinutes < 5) {
        return cached.streak;
      }
    }

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      final state = streakStateFromUserData(data);

      // lastWorkoutDate is written by every session end, so its absence on a
      // user with completed workouts means the counters were never populated.
      final totalWorkouts = (data?['totalWorkouts'] as num?)?.toInt() ?? 0;
      if (state.lastWorkoutDate == null && totalWorkouts > 0) {
        return _calculateUserStreakFromHistory(userId);
      }

      final streak = UserStreak(
        currentStreak: _isStreakStillActive(state.lastWorkoutDate)
            ? state.currentStreak
            : 0,
        longestStreak: state.longestStreak,
        totalWorkouts: totalWorkouts,
        lastWorkoutDate: state.lastWorkoutDate,
        weeklyWorkouts: state.weekStartDate == weekStartFor(DateTime.now())
            ? state.weeklyWorkouts
            : 0,
        buddyWorkouts: (data?['buddyWorkouts'] as num?)?.toInt() ?? 0,
      );

      _streakCache[userId] = (streak: streak, fetchedAt: DateTime.now());
      return streak;
    } catch (e) {
      debugPrint('Error reading streak counters for $userId: $e');
      return UserStreak(currentStreak: 0, longestStreak: 0, totalWorkouts: 0);
    }
  }

  /// A stored streak only still counts if the user trained today or yesterday.
  /// The counter itself is never decayed on read, so this is where a lapsed
  /// streak becomes zero.
  static bool _isStreakStillActive(String? lastWorkoutDate) {
    if (lastWorkoutDate == null) return false;
    final now = DateTime.now();
    return lastWorkoutDate == calendarDay(now) ||
        lastWorkoutDate == calendarDay(now.subtract(const Duration(days: 1)));
  }

  /// Pre-counter fallback: derives the same stats by reading a user's whole
  /// completed-session history. Kept only for user documents written before the
  /// counters existed.
  Future<UserStreak> _calculateUserStreakFromHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('sessions')
          .where('participants', arrayContains: userId)
          .where('status', isEqualTo: 'completed') // Use status for accuracy
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        final streak = UserStreak(
          currentStreak: 0,
          longestStreak: 0,
          totalWorkouts: 0,
          weeklyWorkouts: 0,
        );
        _streakCache[userId] = (streak: streak, fetchedAt: DateTime.now());
        return streak;
      }

      // Monday of the current week (week starts Monday)
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

      // Extract unique dates + count sessions this week
      final workoutDates = <String>{};
      int weeklyCount = 0;
      int buddyCount = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final participants = data['participants'];
        if (participants is List && participants.length > 1) buddyCount++;
        if (data['createdAt'] != null) {
          final date = (data['createdAt'] as Timestamp).toDate();
          final dateStr = date.toIso8601String().split('T')[0];
          workoutDates.add(dateStr);
          if (!date.isBefore(weekStartDate)) weeklyCount++;
        }
      }

      final sortedDates = workoutDates.toList()..sort((a, b) => b.compareTo(a));

      if (sortedDates.isEmpty) {
        final streak = UserStreak(
          currentStreak: 0,
          longestStreak: 0,
          totalWorkouts: snapshot.docs.length,
          weeklyWorkouts: weeklyCount,
          buddyWorkouts: buddyCount,
        );
        _streakCache[userId] = (streak: streak, fetchedAt: DateTime.now());
        return streak;
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .split('T')[0];

      // Check if streak is active
      final isStreakActive =
          sortedDates[0] == today || sortedDates[0] == yesterday;

      // Calculate streaks
      int longestStreak = 0;
      int tempStreak = 0;

      for (int i = 0; i < sortedDates.length; i++) {
        if (i == 0) {
          tempStreak = 1;
        } else {
          final currentDate = DateTime.parse(sortedDates[i]);
          final prevDate = DateTime.parse(sortedDates[i - 1]);
          final diffDays = prevDate.difference(currentDate).inDays;

          if (diffDays == 1) {
            tempStreak++;
          } else {
            longestStreak = longestStreak > tempStreak
                ? longestStreak
                : tempStreak;
            tempStreak = 1;
          }
        }
      }
      longestStreak = longestStreak > tempStreak ? longestStreak : tempStreak;

      final result = UserStreak(
        currentStreak: isStreakActive ? tempStreak : 0,
        longestStreak: longestStreak,
        totalWorkouts: snapshot.docs.length,
        lastWorkoutDate: sortedDates[0],
        weeklyWorkouts: weeklyCount,
        buddyWorkouts: buddyCount,
      );

      _streakCache[userId] = (streak: result, fetchedAt: DateTime.now());
      return result;
    } catch (e) {
      debugPrint('Error calculating streak: $e');
      return UserStreak(currentStreak: 0, longestStreak: 0, totalWorkouts: 0);
    }
  }

  /// Invalidate streak cache for a user.
  void invalidateStreakCache(String userId) {
    _streakCache.remove(userId);
  }

  /// Batch calculate streaks for multiple users.
  Future<Map<String, UserStreak>> batchCalculateStreaks(
    List<String> userIds,
  ) async {
    final results = <String, UserStreak>{};
    final uncachedIds = <String>[];

    // Check cache first
    for (final id in userIds) {
      if (_streakCache.containsKey(id)) {
        final cached = _streakCache[id]!;
        if (DateTime.now().difference(cached.fetchedAt).inMinutes < 5) {
          results[id] = cached.streak;
        } else {
          uncachedIds.add(id);
        }
      } else {
        uncachedIds.add(id);
      }
    }

    if (uncachedIds.isEmpty) return results;

    // For uncached, fetch individually for now as Firestore doesn't support
    // complex batch aggregation queries easily.
    // In production, we'd rely on the denormalized `users/{id}/stats/current` document
    // but here we calculate to be safe or fetch the stats doc.
    // Let's implement fetching from the denormalized stats doc which is faster.

    final chunks = <List<String>>[];
    for (var i = 0; i < uncachedIds.length; i += 10) {
      chunks.add(uncachedIds.skip(i).take(10).toList());
    }

    for (final chunk in chunks) {
      // We can't batch get aggregate queries easily.
      // We will perform parallel fetch of calculateUserStreak which we optimized with cache,
      // but here we want to bypass cache for uncachedIds.
      // Actually, let's just make parallel calls to calculateUserStreak.
      // It will handle the logic.
      final futures = chunk.map((id) => calculateUserStreak(id));
      final streakResults = await Future.wait(futures);

      for (int i = 0; i < chunk.length; i++) {
        results[chunk[i]] = streakResults[i];
      }
    }

    return results;
  }

  /// Update user's streak in their profile.
  Future<void> updateUserStreak(String userId) async {
    invalidateStreakCache(userId); // Clear cache before recalculating
    final stats = await calculateUserStreak(userId);

    final statsData = {
      'currentStreak': stats.currentStreak,
      'longestStreak': stats.longestStreak,
      'totalWorkouts': stats.totalWorkouts,
      'lastWorkoutDate': stats.lastWorkoutDate,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();

    // Update basic stats field on user document (legacy/quick access)
    batch.update(_firestore.collection('users').doc(userId), {
      'stats': statsData,
    });

    // Update stats/current subcollection (used by leaderboard service)
    batch.set(
      _firestore
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('current'),
      statsData,
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// Search for users by unique username (case-insensitive prefix match).
  Future<List<User>> searchUsers(String query) async {
    // Normalize to match stored lowercase handle; strip a leading '@'.
    final normalized = query.trim().toLowerCase().replaceFirst(
      RegExp(r'^@'),
      '',
    );
    if (normalized.isEmpty) return [];

    // isPrivate == false keeps the query inside public list ACL (Z-SEC-001).
    final snapshot = await _firestore
        .collection('users')
        .where('isPrivate', isEqualTo: false)
        .where('usernameLower', isGreaterThanOrEqualTo: normalized)
        .where('usernameLower', isLessThanOrEqualTo: '$normalized\uf8ff')
        .limit(10)
        .get();

    return snapshot.docs.map((doc) => User.fromFirestore(doc)).toList();
  }

  /// Compute and cache buddies (mutual follows) for a user.
  /// Matches RN computeAndCacheBuddies.
  Future<List<String>> computeAndCacheBuddies(String userId) async {
    try {
      // Get users who follow me
      final followersSnapshot = await _firestore
          .collection('follows')
          .where('followeeId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .get();
      final followerIds = followersSnapshot.docs
          .map((d) => d.data()['followerId'] as String)
          .toSet();

      // Get users I follow
      final followingSnapshot = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .get();
      final followingIds = followingSnapshot.docs
          .map((d) => d.data()['followeeId'] as String)
          .toList();

      // Buddies = intersection
      final buddyIds = followingIds
          .where((id) => followerIds.contains(id))
          .toList();

      // Cache in user document
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        await _firestore.collection('users').doc(userId).update({
          'buddies': buddyIds,
          'buddiesUpdatedAt': FieldValue.serverTimestamp(),
        });
      }

      return buddyIds;
    } catch (e) {
      return [];
    }
  }

  /// Get cached buddies for a user.
  Future<List<String>> getCachedBuddies(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists) {
      return (userDoc.data()?['buddies'] as List<dynamic>?)?.cast<String>() ??
          [];
    }
    return [];
  }

  /// Get buddies with presence information.
  /// Matches RN getBuddiesWithPresence.
  Future<List<BuddyWithPresence>> getBuddiesWithPresence(String userId) async {
    var buddyIds = await getCachedBuddies(userId);
    if (buddyIds.isEmpty) {
      buddyIds = await computeAndCacheBuddies(userId);
      if (buddyIds.isEmpty) return [];
    }

    final buddies = <BuddyWithPresence>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final buddyId in buddyIds) {
      final userDoc = await _firestore.collection('users').doc(buddyId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final lastActive = (data['lastActive'] as Timestamp?)?.toDate();
        final isOnline =
            lastActive != null &&
            (now - lastActive.millisecondsSinceEpoch) < onlineThresholdMs;

        buddies.add(
          BuddyWithPresence(
            id: buddyId,
            displayName: data['displayName'] ?? 'Unknown User',
            photoURL: data['photoURL'],
            isOnline: isOnline,
            lastActive: lastActive,
          ),
        );
      }
    }

    return buddies;
  }

  /// Update user's presence.
  /// Matches RN updatePresence.
  Future<void> updatePresence(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  /// Get user's unlocked badges.
  /// Matches RN getUserBadges.
  Future<List<Badge>> getUserBadges(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return [];

    final data = userDoc.data()!;
    final badgeIds = (data['badges'] as List<dynamic>?)?.cast<String>() ?? [];

    return availableBadges
        .where((b) => badgeIds.contains(b.id))
        .map(
          (b) => Badge(
            id: b.id,
            name: b.name,
            icon: b.icon,
            description: b.description,
            criteria: b.criteria,
            unlockedAt: (data['badgeUnlockDates']?[b.id] as Timestamp?)
                ?.toDate(),
          ),
        )
        .toList();
  }

  /// Award a badge to a user.
  Future<void> awardBadge(String userId, String badgeId) async {
    await _firestore.collection('users').doc(userId).update({
      'badges': FieldValue.arrayUnion([badgeId]),
      'badgeUnlockDates.$badgeId': FieldValue.serverTimestamp(),
    });
  }

  /// Check and award badges after session completion.
  /// Matches RN checkAndAwardBadges.
  Future<List<String>> checkAndAwardBadges(
    String userId,
    String sessionId,
  ) async {
    final newlyUnlocked = <String>[];

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final existingBadges =
          (userDoc.data()?['badges'] as List<dynamic>?)?.cast<String>() ?? [];

      final sessionDoc = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .get();
      final sessionData = sessionDoc.data();

      final stats = await calculateUserStreak(userId);

      // Fetched lazily and at most once, no matter how many cheer badges exist.
      int? cheersSent;

      for (final badge in availableBadges) {
        if (existingBadges.contains(badge.id)) continue;

        bool shouldAward = false;

        switch (badge.criteria.type) {
          case BadgeCriteriaType.streak:
            shouldAward = stats.currentStreak >= badge.criteria.threshold;
            break;
          case BadgeCriteriaType.workouts:
            shouldAward = stats.totalWorkouts >= badge.criteria.threshold;
            break;
          case BadgeCriteriaType.earlyBird:
            if (sessionData?['startedAt'] != null) {
              final startHour = (sessionData!['startedAt'] as Timestamp)
                  .toDate()
                  .hour;
              shouldAward = startHour < 7;
            }
            break;
          case BadgeCriteriaType.nightOwl:
            if (sessionData?['startedAt'] != null) {
              final startHour = (sessionData!['startedAt'] as Timestamp)
                  .toDate()
                  .hour;
              shouldAward = startHour >= 22;
            }
            break;
          case BadgeCriteriaType.buddySessions:
            // Already derived from calculateUserStreak's single session read
            // above. Querying the session history again here made every
            // session-end re-scan the user's entire history a second time.
            shouldAward = stats.buddyWorkouts >= badge.criteria.threshold;
            break;
          case BadgeCriteriaType.cheersSent:
            // Cheers sent in this session only, so the count is bounded by one
            // session's events. Read once and reuse across every cheer badge.
            cheersSent ??= (await _firestore
                    .collection('sessions')
                    .doc(sessionId)
                    .collection('events')
                    .where('userId', isEqualTo: userId)
                    .where('type', isEqualTo: 'cheer')
                    .count()
                    .get())
                .count ??
                0;
            shouldAward = cheersSent >= badge.criteria.threshold;
            break;
        }

        if (shouldAward) newlyUnlocked.add(badge.id);
      }

      // One write for the whole batch instead of one per badge.
      if (newlyUnlocked.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update({
          'badges': FieldValue.arrayUnion(newlyUnlocked),
          for (final badgeId in newlyUnlocked)
            'badgeUnlockDates.$badgeId': FieldValue.serverTimestamp(),
        });
      }
    } catch (e, st) {
      // A badge check must never fail the session it runs after, but it also
      // must not vanish — a swallowed error here hid the quota cost of the
      // duplicate history scan this method used to perform.
      debugPrint('Error checking badges for $userId: $e\n$st');
      return const [];
    }

    return newlyUnlocked;
  }

  /// Get badge details by ID.
  Badge? getBadgeById(String badgeId) {
    return availableBadges.cast<Badge?>().firstWhere(
      (b) => b?.id == badgeId,
      orElse: () => null,
    );
  }

  /// Get friend streak comparison for leaderboard.
  Future<List<FriendStreakComparison>> getFriendsStreakComparison(
    String currentUserId,
    List<String> friendIds,
  ) async {
    final allIds = {...friendIds, currentUserId}.toList();
    final streaksMap = await batchCalculateStreaks(allIds);

    // Fetch user profiles for display info
    // Only fetch if not current user (current user info usually available, but for simplicity fetch all or use cache if available)
    // Firestore whereIn limit is 10
    final userProfiles = <String, Map<String, dynamic>>{};

    final chunks = <List<String>>[];
    for (var i = 0; i < allIds.length; i += 10) {
      chunks.add(allIds.skip(i).take(10).toList());
    }

    for (final chunk in chunks) {
      // Handle potential empty chunk which shouldn't happen but good practice
      if (chunk.isEmpty) continue;

      try {
        final docs = await Future.wait(
          chunk.map((id) => _firestore.collection('users').doc(id).get()),
        );

        for (final doc in docs) {
          if (doc.exists) {
            userProfiles[doc.id] = doc.data()!;
          }
        }
      } catch (e) {
        debugPrint('Error fetching user profiles: $e');
      }
    }

    final comparisons = <FriendStreakComparison>[];

    for (final id in allIds) {
      final streak = streaksMap[id];
      final profile = userProfiles[id];

      if (streak != null && profile != null) {
        comparisons.add(
          FriendStreakComparison(
            userId: id,
            displayName: profile['displayName'] ?? 'Unknown',
            photoURL: profile['photoURL'],
            currentStreak: streak.currentStreak,
            longestStreak: streak.longestStreak,
            isCurrentUser: id == currentUserId,
            rank: 0, // Assigned later
            lastWorkoutDate: streak.lastWorkoutDate,
            riskLevel: getStreakRiskLevelSync(streak.lastWorkoutDate),
          ),
        );
      }
    }

    // Sort by streak desc
    comparisons.sort((a, b) => b.currentStreak.compareTo(a.currentStreak));

    // Assign ranks
    final rankedComparisons = <FriendStreakComparison>[];
    for (int i = 0; i < comparisons.length; i++) {
      rankedComparisons.add(
        FriendStreakComparison(
          userId: comparisons[i].userId,
          displayName: comparisons[i].displayName,
          photoURL: comparisons[i].photoURL,
          currentStreak: comparisons[i].currentStreak,
          longestStreak: comparisons[i].longestStreak,
          isCurrentUser: comparisons[i].isCurrentUser,
          rank: i + 1,
          lastWorkoutDate: comparisons[i].lastWorkoutDate,
          riskLevel: comparisons[i].riskLevel,
        ),
      );
    }

    return rankedComparisons;
  }

  /// Get streak leaderboard (wrapper for getFriendsStreakComparison).
  Future<List<FriendStreakComparison>> getStreakLeaderboard(
    String currentUserId,
  ) async {
    var buddies = await getCachedBuddies(currentUserId);
    if (buddies.isEmpty) {
      buddies = await computeAndCacheBuddies(currentUserId);
    }
    return getFriendsStreakComparison(currentUserId, buddies);
  }

  /// Streak Analytics: Get risk level based on last workout date.
  StreakRisk getStreakRiskLevelSync(String? lastWorkoutDateStr) {
    if (lastWorkoutDateStr == null) return StreakRisk.safe;

    final lastWorkoutDate = DateTime.tryParse(lastWorkoutDateStr);
    if (lastWorkoutDate == null) return StreakRisk.safe;

    final now = DateTime.now();

    // If worked out today -> safe
    final today = now.toIso8601String().split('T')[0];
    if (lastWorkoutDateStr == today) return StreakRisk.safe;

    // If worked out yesterday, check time of day
    // If it's after 8pm (20:00) and no workout today -> warning
    // If it's after 10pm (22:00) -> critical
    if (now.hour >= 22) return StreakRisk.critical;
    if (now.hour >= 20) return StreakRisk.warning;

    return StreakRisk.safe;
  }

  /// Streak Analytics: Get next milestone info.
  StreakMilestone getStreakMilestones(int currentStreak) {
    final milestones = [7, 14, 30, 50, 100, 365, 1000];
    int next = milestones.firstWhere(
      (m) => m > currentStreak,
      orElse: () => milestones.last,
    );

    int prev = 0;
    for (final m in milestones) {
      if (m <= currentStreak) {
        prev = m;
      } else {
        break;
      }
    }

    // Progress towards next
    double progress = 0;
    if (next > prev) {
      progress = (currentStreak - prev) / (next - prev);
    }

    // Cap progress at 1.0 (shouldn't happen if logic correct)
    if (progress > 1.0) progress = 1.0;
    if (progress < 0.0) progress = 0.0;

    return StreakMilestone(
      nextMilestone: next,
      progress: progress,
      currentStreak: currentStreak,
    );
  }

  /// Get streak history for trend visualization.
  Future<List<({DateTime date, bool workedOut})>> getStreakHistory(
    String userId, {
    int days = 30,
  }) async {
    final history = <({DateTime date, bool workedOut})>[];
    final now = DateTime.now();

    try {
      final snapshot = await _firestore
          .collection('sessions')
          .where('participants', arrayContains: userId)
          .where('status', isEqualTo: 'completed')
          .where(
            'createdAt',
            isGreaterThan: Timestamp.fromDate(
              now.subtract(Duration(days: days + 1)),
            ),
          )
          .orderBy('createdAt', descending: true)
          .get();

      final workoutDates = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['createdAt'] != null) {
          final date = (data['createdAt'] as Timestamp).toDate();
          workoutDates.add(date.toIso8601String().split('T')[0]);
        }
      }

      for (int i = 0; i < days; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr = date.toIso8601String().split('T')[0];
        history.add((date: date, workedOut: workoutDates.contains(dateStr)));
      }
    } catch (e) {
      debugPrint('Error getting streak history: $e');
    }

    return history;
  }
}

/// User service provider.
final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ref.watch(authFirestoreProvider));
});

/// User streak provider.
final userStreakProvider = FutureProvider.family<UserStreak, String>((
  ref,
  userId,
) async {
  return ref.watch(userServiceProvider).calculateUserStreak(userId);
});

/// User badges provider.
final userBadgesProvider = FutureProvider.family<List<Badge>, String>((
  ref,
  userId,
) async {
  return ref.watch(userServiceProvider).getUserBadges(userId);
});

/// Buddies with presence provider.
final buddiesWithPresenceProvider =
    FutureProvider.family<List<BuddyWithPresence>, String>((ref, userId) async {
      return ref.watch(userServiceProvider).getBuddiesWithPresence(userId);
    });

/// User search provider.
final userSearchProvider = FutureProvider.family<List<User>, String>((
  ref,
  query,
) async {
  return ref.watch(userServiceProvider).searchUsers(query);
});

/// Friends streak comparison provider.
final friendsStreakComparisonProvider = FutureProvider.autoDispose
    .family<List<FriendStreakComparison>, String>((ref, userId) async {
      // Keep alive to cache results for a bit
      final link = ref.keepAlive();
      Timer? timer;

      ref.onDispose(() {
        timer?.cancel();
      });

      // Cache for 5 minutes
      timer = Timer(const Duration(minutes: 5), () {
        link.close();
      });

      return ref.watch(userServiceProvider).getStreakLeaderboard(userId);
    });

/// Streak analytics provider.
final streakHistoryProvider = FutureProvider.autoDispose
    .family<List<({DateTime date, bool workedOut})>, String>((
      ref,
      userId,
    ) async {
      return ref.watch(userServiceProvider).getStreakHistory(userId);
    });

