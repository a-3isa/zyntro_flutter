import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/models.dart';
import '../core/constants/feature_flags.dart';
import '../utils/retry_helper.dart';
import '../utils/offline_manager.dart';
import '../features/auth/auth_providers.dart';
import 'notification_service.dart';
import 'content_filter_service.dart';
import 'media_service.dart';

/// Comment model for posts.
class Comment {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoURL;
  final String text;
  final String type; // 'text' or 'audio'
  final String? audioUrl;
  final DateTime createdAt;
  // T031/T032: true when queued offline, not yet synced to Firestore.
  final bool isPending;

  Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoURL,
    required this.text,
    this.type = 'text',
    this.audioUrl,
    required this.createdAt,
    this.isPending = false,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown',
      authorPhotoURL: data['authorPhotoURL'],
      text: data['text'] ?? '',
      type: data['type'] ?? 'text',
      audioUrl: data['audioUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Pagination cursor for feed queries.
class FeedCursor {
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  FeedCursor({this.lastDoc, required this.hasMore});
}

/// Result of paginated feed queries.
class FeedResult {
  final List<Post> posts;
  final FeedCursor cursor;

  FeedResult({required this.posts, required this.cursor});
}

/// Create post parameters.
class CreatePostParams {
  final String authorId;
  final String sessionId;
  final String visibility; // 'public' | 'private'
  final String title;
  final String type; // 'strength' | 'cardio'
  final SessionSummary summary;
  final String? photoUri;
  final String? buddyId;
  final String? buddyName;

  CreatePostParams({
    required this.authorId,
    required this.sessionId,
    required this.visibility,
    required this.title,
    required this.type,
    required this.summary,
    this.photoUri,
    this.buddyId,
    this.buddyName,
  });
}

/// Post service for managing posts, likes, and comments.
/// Matches React Native postService.ts behavior.
class PostService {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  PostService(this._firestore, this._ref);

  /// Create a new post.
  /// Matches RN createPost - creates doc first, then uploads photo.
  /// Progress callback: 0-10% post creation, 10-90% photo upload, 90-100% finalizing.
  Future<String> createPost(
    CreatePostParams params, {
    void Function(double)? onProgress,
  }) async {
    // Validate post title for profanity
    final contentFilter = _ref.read(contentFilterServiceProvider);
    contentFilter.validateText(params.title, 'post title');

    final postRef = _firestore.collection('posts').doc();
    final postId = postRef.id;

    // Build post data
    final postData = {
      'authorId': params.authorId,
      'sessionId': params.sessionId,
      'visibility': params.visibility,
      'title': params.title,
      'type': params.type,
      'summary': params.summary.toMap(),
      'mediaURLs': <String>[],
      'likesCount': 0,
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      if (params.buddyId != null) 'buddyId': params.buddyId,
      if (params.buddyName != null) 'buddyName': params.buddyName,
    };

    // 1. Create post document first (required for Storage rules)
    onProgress?.call(0.05);
    await withRetry(() => postRef.set(postData));
    onProgress?.call(0.10);

    // 2. Upload photo if provided
    if (params.photoUri != null && params.photoUri!.isNotEmpty) {
      try {
        final mediaService = _ref.read(mediaServiceProvider);
        final photoUrl = await mediaService.uploadPostPhoto(
          filePath: params.photoUri!,
          postId: postId,
          onProgress: (progress) {
            // Scale photo upload progress to 10-90% range
            onProgress?.call(0.10 + progress * 0.80);
          },
        );

        onProgress?.call(0.90);
        // Update post with photo URL
        await withRetry(
          () => postRef.update({
            'mediaURLs': FieldValue.arrayUnion([photoUrl]),
          }),
        );
        onProgress?.call(1.0);
      } catch (e) {
        debugPrint('[PostService] Error uploading photo: $e');
        // Rethrow to let caller handle it for retry
        rethrow;
      }
    } else {
      onProgress?.call(1.0);
    }

    return postId;
  }

  /// Update post with a photo URL (for retry scenarios).
  Future<void> updatePostPhoto(String postId, String photoUrl) async {
    final postRef = _firestore.collection('posts').doc(postId);
    await withRetry(
      () => postRef.update({
        'mediaURLs': FieldValue.arrayUnion([photoUrl]),
      }),
    );
  }

  /// Get a single post by ID.
  Future<Post?> getPost(String postId) async {
    final doc = await _firestore.collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    return Post.fromFirestore(doc);
  }

  /// Get public feed posts.
  /// Matches RN getPublicFeedPosts.
  Future<List<Post>> getPublicFeedPosts({int limit = 20}) async {
    final snapshot = await _firestore
        .collection('posts')
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
  }

  /// Get public posts with pagination.
  /// Matches RN getPublicPosts with cursor support.
  Future<FeedResult> getPublicPosts({
    int limit = 20,
    DocumentSnapshot? startAfterDoc,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snapshot = await query.get();
    final posts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    return FeedResult(
      posts: posts,
      cursor: FeedCursor(
        lastDoc: lastDoc,
        hasMore: snapshot.docs.length == limit,
      ),
    );
  }

  /// Get posts by a specific user.
  /// Matches RN getUserPosts.
  Future<List<Post>> getUserPosts(String userId, {int limit = 20}) async {
    final snapshot = await _firestore
        .collection('posts')
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
  }

  /// Real-time stream of posts by a specific user.
  Stream<List<Post>> watchUserPosts(String userId, {int limit = 20}) {
    return _firestore
        .collection('posts')
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Post.fromFirestore(doc)).toList());
  }

  // Prefetch cache
  final Map<String, FeedResult> _prefetchCache = {};

  /// Prefetch the next page of following posts.
  Future<void> prefetchNextPage({
    required String currentUserId,
    required List<String> followingIds,
    required DocumentSnapshot? startAfterDoc,
    int limit = 20,
  }) async {
    final cacheKey = '${currentUserId}_${startAfterDoc?.id ?? "head"}';
    if (_prefetchCache.containsKey(cacheKey)) return;

    try {
      final result = await getFollowingPosts(
        currentUserId: currentUserId,
        followingIds: followingIds,
        limit: limit,
        startAfterDoc: startAfterDoc,
        isPrefetch: true, // Internal flag to avoid loop
      );
      _prefetchCache[cacheKey] = result;
    } catch (e) {
      debugPrint('[PostService] Prefetch failed: $e');
    }
  }

  /// Get posts from followed users.
  /// Matches RN getFollowingPosts with optimized pagination strategy.
  Future<FeedResult> getFollowingPosts({
    required String currentUserId,
    required List<String> followingIds,
    int limit = 20,
    DocumentSnapshot? startAfterDoc,
    bool isPrefetch = false,
  }) async {
    // Check prefetch cache
    final cacheKey = '${currentUserId}_${startAfterDoc?.id ?? "head"}';
    if (!isPrefetch && _prefetchCache.containsKey(cacheKey)) {
      final cached = _prefetchCache.remove(cacheKey)!;
      // Trigger next prefetch
      if (cached.cursor.hasMore) {
        prefetchNextPage(
          currentUserId: currentUserId,
          followingIds: followingIds,
          startAfterDoc: cached.cursor.lastDoc,
          limit: limit,
        );
      }
      return cached;
    }

    // Include user's own posts
    final allIds = {...followingIds, currentUserId}.toList();

    if (allIds.isEmpty) {
      return FeedResult(posts: [], cursor: FeedCursor(hasMore: false));
    }

    // Unified chunking strategy (batches of 10) for consistent pagination
    final chunks = <List<String>>[];
    for (var i = 0; i < allIds.length; i += 10) {
      chunks.add(allIds.sublist(i, (i + 10).clamp(0, allIds.length)));
    }

    // Prepare queries for all chunks
    // We use a unified createdAt cursor if startAfterDoc is provided
    DateTime? lastCreatedAt;
    if (startAfterDoc != null) {
      final data = startAfterDoc.data() as Map<String, dynamic>?;
      lastCreatedAt = (data?['createdAt'] as Timestamp?)?.toDate();
    }

    final futures = chunks.map((chunk) {
      Query<Map<String, dynamic>> query = _firestore
          .collection('posts')
          .where('authorId', whereIn: chunk)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastCreatedAt != null) {
        query = query.startAfter([Timestamp.fromDate(lastCreatedAt)]);
      }

      return query.get();
    });

    final snapshots = await Future.wait(futures);

    // Merge all results
    final allPosts = <Post>[];
    var anyChunkHasMore = false;

    for (final snapshot in snapshots) {
      if (snapshot.docs.length >= limit) {
        anyChunkHasMore = true;
      }

      for (final doc in snapshot.docs) {
        final post = Post.fromFirestore(doc);
        // Private posts are personal records only — never show in the social feed.
        if (post.visibility == 'private') continue;
        allPosts.add(post);
      }
    }

    // Filter duplicates and sort
    final uniquePosts = <String, Post>{};
    for (final post in allPosts) {
      uniquePosts[post.id] = post;
    }

    final sortedPosts = uniquePosts.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Limit to requested size
    final resultPosts = sortedPosts.take(limit).toList();

    // Determine last doc for cursor
    DocumentSnapshot? newLastDoc;
    if (resultPosts.isNotEmpty) {
      final lastPostId = resultPosts.last.id;
      // Search in all snapshots
      for (final snap in snapshots) {
        for (final doc in snap.docs) {
          if (doc.id == lastPostId) {
            newLastDoc = doc;
            break;
          }
        }
        if (newLastDoc != null) break;
      }
    }

    final result = FeedResult(
      posts: resultPosts,
      cursor: FeedCursor(
        lastDoc: newLastDoc,
        hasMore: anyChunkHasMore || resultPosts.length >= limit,
      ),
    );

    // Trigger prefetch for next page if not prefetching
    if (!isPrefetch && result.cursor.hasMore) {
      prefetchNextPage(
        currentUserId: currentUserId,
        followingIds: followingIds,
        startAfterDoc: result.cursor.lastDoc,
        limit: limit,
      );
    }

    return result;
  }

  /// Get recent posts from specific buddies.
  /// Filters for 'public' and 'followers' visibility.
  Future<List<Post>> getBuddiesRecentPosts(
    List<String> buddyIds, {
    int limit = 15,
  }) async {
    if (buddyIds.isEmpty) return [];

    // Ensure at most 10 buddies per query for 'whereIn'.
    final safeBuddyIds = buddyIds.take(10).toList();

    // Query 1: Public posts
    final publicSnapshot = await _firestore
        .collection('posts')
        .where('authorId', whereIn: safeBuddyIds)
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    // Query 2: Followers posts
    final followersSnapshot = await _firestore
        .collection('posts')
        .where('authorId', whereIn: safeBuddyIds)
        .where('visibility', isEqualTo: 'followers')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    final allDocs = [...publicSnapshot.docs, ...followersSnapshot.docs];

    // Deduplicate and Convert
    final uniquePosts = <String, Post>{};
    for (final doc in allDocs) {
      if (!uniquePosts.containsKey(doc.id)) {
        uniquePosts[doc.id] = Post.fromFirestore(doc);
      }
    }

    // Sort by createdAt desc
    final sortedPosts = uniquePosts.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sortedPosts.take(limit).toList();
  }

  // ==================== REACTIONS (LIKES & OTHERS) ====================

  /// React to a post.
  /// Defaults to [ReactionType.like] if type not provided.
  Future<void> reactToPost(
    String postId,
    String userId, {
    String? userName,
    ReactionType type = ReactionType.fire,
  }) async {
    final reactionRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('reactions')
        .doc(userId);

    final postRef = _firestore.collection('posts').doc(postId);

    await withRetry(
      () => _firestore.runTransaction((transaction) async {
        final reactionDoc = await transaction.get(reactionRef);

        if (reactionDoc.exists) {
          // Already reacted, check if type changed?
          // If we want to support changing reaction, we'd update 'type'.
          // For now, if already exists, we might just update valid
          final currentType = reactionDoc.data()?['type'];
          if (currentType != type.value) {
            transaction.update(reactionRef, {
              'type': type.value,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          return;
        }

        transaction.set(reactionRef, {
          'type': type.value,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(postRef, {'likesCount': FieldValue.increment(1)});
      }),
    );

    // Notify (unawaited for speed)
    unawaited(_notifyPostReaction(postId, userId, userName, type));
  }

  // T029: likePost with offline queue fallback. Uses stable ID to deduplicate.
  Future<void> likePost(String postId, String userId, {String? userName}) {
    final offlineManager = _ref.read(offlineManagerProvider);
    if (!offlineManager.isOnline) {
      return offlineManager.queueOperation(
        'like_post',
        {'postId': postId, 'userId': userId, if (userName != null) 'userName': userName},
        id: 'like_${postId}_$userId',
      );
    }
    return reactToPost(
      postId,
      userId,
      userName: userName,
      type: ReactionType.fire,
    );
  }

  Future<void> _notifyPostReaction(
    String postId,
    String userId,
    String? userName,
    ReactionType type,
  ) async {
    try {
      final post = await getPost(postId);
      if (post != null && post.authorId != userId) {
        // Notification service usually handles generic 'like', we pass type or use slightly different title?
        // We'll use the existing notifyPostLike for now as 'reaction'
        await _ref
            .read(notificationServiceProvider)
            .notifyPostLike(
              recipientId: post.authorId,
              likerId: userId,
              likerName: userName ?? 'Someone',
              postId: postId,
            );
      }
    } catch (e) {
      debugPrint('[PostService] Error sending reaction notification: $e');
    }
  }

  /// Remove reaction (Unlike) a post.
  Future<void> removeReaction(String postId, String userId) async {
    final batch = _firestore.batch();

    final reactionRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('reactions')
        .doc(userId);

    batch.delete(reactionRef);

    final postDoc = await _firestore.collection('posts').doc(postId).get();
    if (postDoc.exists) {
      final currentLikes = postDoc.data()?['likesCount'] ?? 0;
      if (currentLikes > 0) {
        batch.update(_firestore.collection('posts').doc(postId), {
          'likesCount': FieldValue.increment(-1),
        });
      }
    }

    await withRetry(() => batch.commit());
  }

  // T030: unlikePost with offline queue fallback. Uses stable ID to deduplicate.
  Future<void> unlikePost(String postId, String userId) {
    final offlineManager = _ref.read(offlineManagerProvider);
    if (!offlineManager.isOnline) {
      return offlineManager.queueOperation(
        'unlike_post',
        {'postId': postId, 'userId': userId},
        id: 'unlike_${postId}_$userId',
      );
    }
    return removeReaction(postId, userId);
  }

  /// Check if user has reacted to a post.
  Future<ReactionType?> getUserReaction(String postId, String userId) async {
    final reactionDoc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('reactions')
        .doc(userId)
        .get();

    if (!reactionDoc.exists) return null;
    return ReactionType.fromString(reactionDoc.data()?['type'] ?? 'like');
  }

  // Deprecated wrapper returning bool
  Future<bool> hasUserLikedPost(String postId, String userId) async {
    final reaction = await getUserReaction(postId, userId);
    return reaction != null;
  }

  /// Get reaction counts by type for a post.
  /// Returns a map of ReactionType to count.
  Future<Map<ReactionType, int>> getReactionCounts(String postId) async {
    final snapshot = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('reactions')
        .get();

    final counts = <ReactionType, int>{};
    for (final doc in snapshot.docs) {
      final type = ReactionType.fromString(doc.data()['type'] ?? 'like');
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  /// Get all reactions for a post with user IDs and types.
  Future<List<Map<String, dynamic>>> getPostReactions(
    String postId, {
    int limit = 100,
  }) async {
    final snapshot = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('reactions')
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      return {
        'userId': doc.id,
        'type': doc.data()['type'] ?? 'like',
        'createdAt': doc.data()['createdAt'],
      };
    }).toList();
  }

  /// Get all user IDs who reacted to a post.
  Future<List<String>> getPostLikes(String postId) async {
    final snapshot = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('reactions')
        // .where('type', isEqualTo: 'like') // Optional: filter by type? usually "likes" implies all reactions
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  // ==================== COMMENTS ====================

  /// Add a comment to a post.
  /// Matches RN addComment.
  @Deprecated(
    'Comments are disabled for MVP. Will be enabled in future release.',
  )
  Future<String> addComment({
    required String postId,
    required String userId,
    required String userName,
    String? userPhotoURL,
    required String text,
    String? audioUrl,
  }) async {
    // Validate comment text for profanity (only for text comments, not audio)
    if (audioUrl == null && text.isNotEmpty) {
      final contentFilter = _ref.read(contentFilterServiceProvider);
      contentFilter.validateText(text, 'comment');
    }

    final batch = _firestore.batch();

    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc();

    batch.set(commentRef, {
      'authorId': userId,
      'authorName': userName,
      'authorPhotoURL': userPhotoURL,
      'text': text,
      'type': audioUrl != null ? 'audio' : 'text',
      'createdAt': FieldValue.serverTimestamp(),
      if (audioUrl != null) 'audioUrl': audioUrl,
    });

    batch.update(_firestore.collection('posts').doc(postId), {
      'commentsCount': FieldValue.increment(1),
    });

    await withRetry(() => batch.commit());

    // Notify (unawaited)
    unawaited(
      _notifyPostComment(postId, userId, userName, text, commentRef.id),
    );

    return commentRef.id;
  }

  Future<void> _notifyPostComment(
    String postId,
    String userId,
    String userName,
    String text,
    String commentId,
  ) async {
    try {
      final post = await getPost(postId);
      if (post != null && post.authorId != userId) {
        await _ref
            .read(notificationServiceProvider)
            .notifyPostComment(
              recipientId: post.authorId,
              commenterId: userId,
              commenterName: userName,
              postId: postId,
              commentId: commentId,
              commentText: text,
            );
      }
    } catch (e) {
      debugPrint('[PostService] Error sending comment notification: $e');
    }
  }

  /// Get comments for a post.
  @Deprecated(
    'Comments are disabled for MVP. Will be enabled in future release.',
  )
  Future<List<Comment>> getComments(String postId, {int limit = 50}) async {
    final snapshot = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList();
  }

  /// Subscribe to real-time comment updates.
  /// Matches RN subscribeToComments.
  @Deprecated(
    'Comments are disabled for MVP. Will be enabled in future release.',
  )
  Stream<List<Comment>> subscribeToComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList(),
        );
  }
}

/// Post service provider.
final postServiceProvider = Provider<PostService>((ref) {
  return PostService(ref.watch(authFirestoreProvider), ref);
});

/// Public feed posts provider.
// Using autoDispose so it doesn't hold stale data if user leaves feed
final publicFeedProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  // Keep alive for 5 minutes (caching strategy)
  final link = ref.keepAlive();
  Timer? timer;

  ref.onDispose(() => timer?.cancel());
  ref.onCancel(() {
    timer = Timer(const Duration(minutes: 5), () => link.close());
  });
  ref.onResume(() => timer?.cancel());

  return ref.watch(postServiceProvider).getPublicFeedPosts();
});

/// User posts provider — real-time stream so the grid updates without a pull-to-refresh.
final userPostsProvider = StreamProvider.family<List<Post>, String>((
  ref,
  userId,
) {
  return ref.watch(postServiceProvider).watchUserPosts(userId);
});

/// Comments stream provider.
final commentsProvider = StreamProvider.family<List<Comment>, String>((
  ref,
  postId,
) {
  if (!FeatureFlags.isCommentsEnabled) {
    return Stream.value([]);
  }
  // ignore: deprecated_member_use_from_same_package
  return ref.watch(postServiceProvider).subscribeToComments(postId);
});
