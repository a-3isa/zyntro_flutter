import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/constants.dart';
import '../core/models/models.dart';
import '../features/auth/auth_providers.dart';
import 'post_service.dart';
import 'user_service.dart';
import 'user_cache_service.dart';

/// Workout service for logging and retrieving workout history.
/// Matches React Native workoutService.ts behavior.
class WorkoutService {
  final FirebaseFirestore _firestore;

  WorkoutService(this._firestore);

  /// Log a completed workout from a session.
  /// Matches RN logWorkout.
  Future<void> logWorkout(Session session) async {
    if (session.endedAt == null) return;

    final workoutRef = _firestore.collection('workouts').doc();

    // Store the workout type value (string) for flexibility
    final workoutData = {
      'userId': session.hostId,
      'sessionId': session.id,
      'type': session.type,
      'title': session.title,
      'summary': session.summary?.toMap() ?? {},
      'endedAt': session.endedAt!.toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    await workoutRef.set(workoutData);
  }

  /// Get workouts for a specific user with pagination.
  /// Matches RN getUserWorkouts.
  Future<WorkoutQueryResult> getUserWorkouts(
    String userId, {
    int limit = 20,
    DocumentSnapshot? startAfterDoc,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('workouts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snapshot = await query.get();
    final workouts = snapshot.docs
        .map((doc) => Workout.fromFirestore(doc))
        .toList();
    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    return WorkoutQueryResult(
      workouts: workouts,
      lastDoc: lastDoc,
      hasMore: snapshot.docs.length == limit,
    );
  }

  /// Get workouts for a specific user filtered by workout type.
  /// Includes legacy type support (strength→gym, cardio→running, both→other).
  Future<WorkoutQueryResult> getWorkoutsByType(
    String userId,
    WorkoutType type, {
    int limit = 20,
    DocumentSnapshot? startAfterDoc,
  }) async {
    // Include both new type value and any legacy equivalents
    final typeValues = _getTypeValuesWithLegacy(type);

    Query<Map<String, dynamic>> query = _firestore
        .collection('workouts')
        .where('userId', isEqualTo: userId)
        .where('type', whereIn: typeValues)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snapshot = await query.get();
    final workouts = snapshot.docs
        .map((doc) => Workout.fromFirestore(doc))
        .toList();
    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    return WorkoutQueryResult(
      workouts: workouts,
      lastDoc: lastDoc,
      hasMore: snapshot.docs.length == limit,
    );
  }

  /// Get type values including legacy equivalents for backward compatibility.
  /// strength → gym, cardio → running, both → other
  List<String> _getTypeValuesWithLegacy(WorkoutType type) {
    final values = <String>{type.value};

    // Add legacy equivalents
    switch (type) {
      case WorkoutType.gym:
        values.add('strength'); // Legacy 'strength' maps to 'gym'
        break;
      case WorkoutType.running:
        values.add('cardio'); // Legacy 'cardio' maps to 'running'
        break;
      case WorkoutType.other:
        values.add('both'); // Legacy 'both' maps to 'other'
        break;
      default:
        break;
    }

    return values.toList();
  }

  /// Get legacy type strings that map to a category.
  List<String> _getLegacyTypesForCategory(String category) {
    final legacyTypes = <String>[];

    switch (category) {
      case 'strength':
        legacyTypes.add('strength'); // Legacy 'strength' is strength category
        break;
      case 'cardio':
        legacyTypes.add('cardio'); // Legacy 'cardio' is cardio category
        break;
      case 'mixed':
        legacyTypes.add('both'); // Legacy 'both' is mixed category
        break;
      default:
        break;
    }

    return legacyTypes;
  }

  /// Get workouts for a specific user filtered by category (strength, cardio, etc.).
  /// Includes legacy type support for backward compatibility.
  Future<WorkoutQueryResult> getWorkoutsByCategory(
    String userId,
    String category, {
    int limit = 20,
    DocumentSnapshot? startAfterDoc,
  }) async {
    // Get all workout types that belong to this category
    final typesInCategory = WorkoutType.values
        .where((t) => t.category == category)
        .map((t) => t.value)
        .toList();

    // Add legacy type strings for backward compatibility
    typesInCategory.addAll(_getLegacyTypesForCategory(category));

    // Remove duplicates
    final uniqueTypes = typesInCategory.toSet().toList();

    if (uniqueTypes.isEmpty) {
      return WorkoutQueryResult(workouts: [], hasMore: false);
    }

    // Firestore 'whereIn' limit is 10, which should be fine for categories
    Query<Map<String, dynamic>> query = _firestore
        .collection('workouts')
        .where('userId', isEqualTo: userId)
        .where('type', whereIn: uniqueTypes)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snapshot = await query.get();
    final workouts = snapshot.docs
        .map((doc) => Workout.fromFirestore(doc))
        .toList();
    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    return WorkoutQueryResult(
      workouts: workouts,
      lastDoc: lastDoc,
      hasMore: snapshot.docs.length == limit,
    );
  }

  /// Get workouts for a list of buddy IDs (for feed carousel).
  /// Matches RN getBuddiesRecentWorkouts.
  Future<List<Workout>> getBuddiesRecentWorkouts(
    List<String> buddyIds, {
    int limit = 10,
  }) async {
    if (buddyIds.isEmpty) return [];

    // Firestore 'whereIn' limit is 10
    final safeBuddyIds = buddyIds.take(10).toList();

    final snapshot = await _firestore
        .collection('workouts')
        .where('userId', whereIn: safeBuddyIds)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => Workout.fromFirestore(doc)).toList();
  }

  /// Get user's workout count.
  ///
  /// Counted with an aggregate rather than by reading every workout document:
  /// the old version's cost grew with every workout the user had ever logged,
  /// purely to produce a number.
  Future<int> getUserWorkoutCount(String userId) async {
    final snapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: userId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Get user's workout count by type.
  Future<int> getWorkoutCountByType(String userId, WorkoutType type) async {
    final snapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: type.value)
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}

/// Workout service provider.
final workoutServiceProvider = Provider<WorkoutService>((ref) {
  return WorkoutService(ref.watch(authFirestoreProvider));
});

/// User workouts provider.
///
/// autoDispose is what makes the keepAlive window below mean anything:
/// ref.keepAlive() is a no-op on a provider that never disposes, so this
/// previously cached forever rather than for the two minutes it claimed.
final userWorkoutsProvider = FutureProvider.autoDispose
    .family<WorkoutQueryResult, String>((ref, userId) async {
  // Cache for 2 minutes to prevent repeated fetches on tab switch
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 2), () => link.close());
  ref.onDispose(() => timer.cancel());

  return ref.watch(workoutServiceProvider).getUserWorkouts(userId);
});

/// Buddies recent workouts provider.
final buddiesWorkoutsProvider =
    FutureProvider.family<List<Workout>, List<String>>((ref, buddyIds) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 2), () => link.close());
      ref.onDispose(() => timer.cancel());

      return ref
          .watch(workoutServiceProvider)
          .getBuddiesRecentWorkouts(buddyIds);
    });

/// Friends recent activity provider.
/// Fetches recent workouts and posts from buddies, respecting visibility and privacy.
final friendsRecentActivityProvider =
    FutureProvider.family<List<ActivityItem>, String>((ref, userId) async {
      final userService = ref.watch(userServiceProvider);
      final postService = ref.watch(postServiceProvider);
      final workoutService = ref.watch(workoutServiceProvider);
      final userCacheService = ref.watch(userCacheServiceProvider);

      // 1. Get buddy IDs using UserService (cached list)
      final buddyIds = await userService.getCachedBuddies(userId);
      if (buddyIds.isEmpty) return [];

      // Limit to 10 buddies for queries
      final safeBuddyIds = buddyIds.take(10).toList();

      // 2. Fetch workouts and posts in parallel
      // PostService.getBuddiesRecentPosts returns listable public posts only
      final results = await Future.wait([
        workoutService.getBuddiesRecentWorkouts(safeBuddyIds),
        postService.getBuddiesRecentPosts(safeBuddyIds),
      ]);

      final workouts = results[0] as List<Workout>;
      final posts = results[1] as List<Post>;

      // 3. Batch fetch users for all authors
      final allAuthorIds = {
        ...workouts.map((w) => w.userId),
        ...posts.map((p) => p.authorId),
      }.toList();

      if (allAuthorIds.isNotEmpty) {
        await userCacheService.fetchUsers(allAuthorIds);
      }

      // 4. Convert to ActivityItem
      final activities = <ActivityItem>[];

      for (final workout in workouts) {
        final user = userCacheService.getUserSync(workout.userId);
        if (user != null) {
          activities.add(ActivityItem.fromWorkout(workout, user));
        }
      }

      for (final post in posts) {
        final user = userCacheService.getUserSync(post.authorId);
        if (user != null) {
          activities.add(ActivityItem.fromPost(post, user));
        }
      }

      // 5. Sort by timestamp descending
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return activities;
    });

