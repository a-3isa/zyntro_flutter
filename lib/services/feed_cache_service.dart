import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/models.dart';

class FeedCacheService {
  static const String _key = 'zyntro_feed_cache';
  static const int _maxPosts = 20;
  static const Duration _staleTTL = Duration(days: 7);

  final SharedPreferences _prefs;

  FeedCacheService(this._prefs);

  List<Post> readCachePosts() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return [];
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final postsJson = data['posts'] as List<dynamic>;
      return postsJson
          .map((p) => _postFromMap(p as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> writeCachePosts(List<Post> posts) async {
    final sorted = [...posts]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final capped = sorted.take(_maxPosts).toList();
    final data = {
      'cachedAt': DateTime.now().toIso8601String(),
      'posts': capped.map(_postToMap).toList(),
    };
    await _prefs.setString(_key, jsonEncode(data));
  }

  Future<void> clearCache() async {
    await _prefs.remove(_key);
  }

  bool get isStale {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = DateTime.parse(data['cachedAt'] as String);
      return DateTime.now().difference(cachedAt) > _staleTTL;
    } catch (_) {
      return false;
    }
  }

  bool get isEmpty => _prefs.getString(_key) == null;

  DateTime? get cachedAt {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return DateTime.parse(data['cachedAt'] as String);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _postToMap(Post p) => {
    'id': p.id,
    'authorId': p.authorId,
    'sessionId': p.sessionId,
    'visibility': p.visibility,
    'title': p.title,
    'type': p.type,
    'summary': p.summary.toMap(),
    if (p.mediaURLs != null) 'mediaURLs': p.mediaURLs,
    if (p.buddyId != null) 'buddyId': p.buddyId,
    if (p.buddyName != null) 'buddyName': p.buddyName,
    'likesCount': p.likesCount,
    'commentsCount': p.commentsCount,
    'createdAt': p.createdAt.toIso8601String(),
    if (p.reactionCounts != null) 'reactionCounts': p.reactionCounts,
  };

  Post _postFromMap(Map<String, dynamic> m) => Post(
    id: m['id'] as String,
    authorId: m['authorId'] as String,
    sessionId: m['sessionId'] as String,
    visibility: m['visibility'] as String,
    title: m['title'] as String,
    type: m['type'] as String,
    summary: SessionSummary.fromMap(
      (m['summary'] as Map<String, dynamic>?) ?? {},
    ),
    mediaURLs: (m['mediaURLs'] as List<dynamic>?)?.cast<String>(),
    buddyId: m['buddyId'] as String?,
    buddyName: m['buddyName'] as String?,
    likesCount: m['likesCount'] as int? ?? 0,
    commentsCount: m['commentsCount'] as int? ?? 0,
    createdAt: DateTime.parse(m['createdAt'] as String),
    reactionCounts: (m['reactionCounts'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, v as int),
    ),
  );
}

/// Injected at startup via ProviderContainer override with the resolved
/// SharedPreferences instance (see main.dart).
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main() '
    'with sharedPreferencesProvider.overrideWithValue(prefs)',
  );
});

final feedCacheServiceProvider = Provider<FeedCacheService>((ref) {
  return FeedCacheService(ref.watch(sharedPreferencesProvider));
});
