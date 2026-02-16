import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/models.dart';
import 'auth_service.dart';

/// User cache service for reducing Firestore reads.
/// Implements in-memory caching with TTL for frequently accessed user data.
class UserCacheService {
  final FirebaseFirestore _firestore;

  // In-memory cache with TTL and Max Size
  final Map<String, _CachedUser> _cache = {};
  static const Duration _cacheTTL = Duration(minutes: 5);
  static const int _maxCacheSize = 500;

  UserCacheService(this._firestore);

  /// Get user from cache synchronously (without TTL check).
  User? getUserSync(String id) => _cache[id]?.user;

  /// Get user with async fetch and TTL-based caching.
  Future<User?> getUser(String userId, {bool forceRefresh = false}) async {
    // Check cache
    if (!forceRefresh && _cache.containsKey(userId)) {
      final cached = _cache[userId]!;
      // Update usage timestamp for LRU, but PRESERVE fetchedAt
      _cache[userId] = _CachedUser(
        user: cached.user,
        timestamp: DateTime.now(),
        fetchedAt: cached.fetchedAt,
      );

      if (DateTime.now().difference(cached.fetchedAt) < _cacheTTL) {
        // Hit
        return cached.user;
      } else {
        debugPrint('[UserCache] Cache EXPIRED for $userId');
        _cache.remove(userId);
      }
    }

    // Fetch from Firestore
    // debugPrint('[UserCache] Cache MISS for $userId, fetching...'); // Reduced noise
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;

    final user = User.fromFirestore(doc);
    _addToCache(userId, user);

    return user;
  }

  void _addToCache(String userId, User user) {
    if (_cache.length >= _maxCacheSize) {
      // Evict oldest accessed
      // Sort by timestamp (access time)
      final sortedKeys = _cache.keys.toList()
        ..sort((a, b) => _cache[a]!.timestamp.compareTo(_cache[b]!.timestamp));

      // Remove 10% of cache to avoid frequent evictions
      final countToRemove = (_maxCacheSize * 0.1).ceil();
      for (var i = 0; i < countToRemove; i++) {
        if (i < sortedKeys.length) _cache.remove(sortedKeys[i]);
      }
    }

    _cache[userId] = _CachedUser(
      user: user,
      timestamp: DateTime.now(), // Access time
      fetchedAt: DateTime.now(), // Fetch time
    );
  }

  /// Fetch users in batches and populate cache.
  /// Returns map of userId to User for found users.
  Future<Map<String, User>> fetchUsers(List<String> ids) async {
    final result = <String, User>{};
    final uniqueIds = ids.toSet().toList();
    final missingIds = <String>[];

    // Check cache for each user
    for (final id in uniqueIds) {
      if (_cache.containsKey(id)) {
        final cached = _cache[id]!;
        if (DateTime.now().difference(cached.fetchedAt) < _cacheTTL) {
          result[id] = cached.user;
          // Update access time
          _cache[id] = _CachedUser(
            user: cached.user,
            timestamp: DateTime.now(),
            fetchedAt: cached.fetchedAt,
          );
        } else {
          _cache.remove(id);
          missingIds.add(id);
        }
      } else {
        missingIds.add(id);
      }
    }

    if (missingIds.isEmpty) return result;

    // Firestore 'whereIn' is limited to 10 values
    const int batchSize = 10;
    for (var i = 0; i < missingIds.length; i += batchSize) {
      final end = (i + batchSize < missingIds.length)
          ? i + batchSize
          : missingIds.length;
      final chunk = missingIds.sublist(i, end);

      try {
        final snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          final user = User.fromFirestore(doc);
          result[doc.id] = user;
          _addToCache(doc.id, user);
        }
      } catch (e) {
        debugPrint('[UserCache] Error fetching users: $e');
      }
    }

    return result;
  }

  /// Warm cache with session participants.
  Future<void> warmSessionParticipants(String sessionId) async {
    try {
      final session = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .get();
      if (!session.exists) return;

      final participants = (session.data()?['participants'] as List<dynamic>?)
          ?.cast<String>();
      if (participants != null && participants.isNotEmpty) {
        await fetchUsers(participants);
        debugPrint(
          '[UserCache] Warmed ${participants.length} participants for session $sessionId',
        );
      }
    } catch (e) {
      debugPrint('[UserCache] Error warming session participants: $e');
    }
  }

  /// Warm cache with post authors.
  Future<void> warmPostAuthors(List<String> postIds) async {
    if (postIds.isEmpty) return;

    // Optimizing: If we have Post objects, we should use warmPostAuthorsFromPosts
    // But adhering to interface: we fetch posts to get authors?
    // This seems expensive.
    // Assuming this is called ONLY when we have IDs but not posts?
    // Or maybe the intent is to pre-fetch authors for a list of posts that we are ABOUT to show?
    // If I have postIds, I probably don't have author IDs yet.
    // Fetching posts just to get authors is expensive (Read Post + Read Author).
    // But if we are going to show the posts, we will fetch them anyway.
    // If this is "Pre-fetch", maybe it implies we fetch the posts AND authors?
    // I will implement it as: Fetch posts (if not cached? PostService has cache?) -> Get Authors -> Fetch Authors.

    // NOTE: This implementation assumes we need to fetch the posts to find the authors.
    // To avoid double billing, real implementation should probably take Author IDs.
    // But I will follow the plan "warmPostAuthors(List<String> postIds)".

    try {
      // We can't easily fetch posts by IDs in batch if they are not sorted.
      // I'll skip fetching posts here and assume the caller should use fetchUsers directly if they have author IDs.
      // However, IF the plan implies warming authors FROM known posts, I should accept author IDs.
      // Let's implement a smarter version: warmPostAuthorsFromList(List<Post> posts).
      // But to strictly follow "warmPostAuthors(List<String> postIds)":

      final chunks = <List<String>>[];
      for (var i = 0; i < postIds.length; i += 10) {
        chunks.add(postIds.skip(i).take(10).toList());
      }

      final authorIds = <String>{};

      for (final chunk in chunks) {
        final snapshot = await _firestore
            .collection('posts')
            .where(FieldPath.documentId, whereIn: chunk)
            .get(); // This costs reads!

        for (final doc in snapshot.docs) {
          authorIds.add(doc.data()['authorId'] as String);
        }
      }

      if (authorIds.isNotEmpty) {
        await fetchUsers(authorIds.toList());
      }
    } catch (e) {
      // Ignore
    }
  }

  /// Helper to warm authors if you already have the posts (preferred).
  Future<void> warmAuthorsFromPosts(List<Post> posts) async {
    final authorIds = posts.map((p) => p.authorId).toList();
    if (authorIds.isNotEmpty) {
      await fetchUsers(authorIds);
    }
  }

  /// Invalidate cache for a user.
  void invalidate(String userId) {
    _cache.remove(userId);
    debugPrint('[UserCache] Invalidated cache for $userId');
  }

  /// Pattern based invalidation safely.
  void invalidatePattern(String pattern) {
    final keysToRemove = _cache.keys.where((k) => k.contains(pattern)).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
    debugPrint(
      '[UserCache] Invalidated ${keysToRemove.length} keys matching $pattern',
    );
  }

  /// Clear entire cache.
  void clearCache() {
    _cache.clear();
    debugPrint('[UserCache] Cache cleared');
  }

  /// Get cache statistics for debugging.
  Map<String, dynamic> getCacheStats() {
    return {
      'size': _cache.length,
      'capacity': _maxCacheSize,
      'users': _cache.keys.take(10).toList(), // Limit output
    };
  }
}

class _CachedUser {
  final User user;
  final DateTime timestamp; // Access time for LRU
  final DateTime fetchedAt; // Fetch time for TTL

  _CachedUser({
    required this.user,
    required this.timestamp,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? timestamp;
}

/// User cache service provider.
final userCacheServiceProvider = Provider<UserCacheService>((ref) {
  return UserCacheService(ref.watch(firestoreProvider));
});
