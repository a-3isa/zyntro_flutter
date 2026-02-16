import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import 'auth_service.dart';

/// User presence status in a session.
enum PresenceStatus { online, away, offline }

extension PresenceStatusExtension on PresenceStatus {
  String get value {
    switch (this) {
      case PresenceStatus.online:
        return 'online';
      case PresenceStatus.away:
        return 'away';
      case PresenceStatus.offline:
        return 'offline';
    }
  }

  static PresenceStatus fromString(String value) {
    switch (value) {
      case 'online':
        return PresenceStatus.online;
      case 'away':
        return PresenceStatus.away;
      default:
        return PresenceStatus.offline;
    }
  }
}

/// User presence data.
class UserPresence {
  final String userId;
  final PresenceStatus status;
  final DateTime lastChanged;
  final bool isTyping; // Added typing status

  UserPresence({
    required this.userId,
    required this.status,
    required this.lastChanged,
    this.isTyping = false,
  });

  factory UserPresence.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserPresence(
      userId: doc.id,
      status: PresenceStatusExtension.fromString(data['status'] ?? 'offline'),
      lastChanged:
          (data['lastChanged'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isTyping: data['isTyping'] ?? false,
    );
  }
}

class PresenceService {
  final FirebaseFirestore _firestore;

  // In-memory cache for fallback
  final Map<String, Map<String, PresenceStatus>> _presenceCache = {};

  PresenceService(this._firestore);

  /// Get cached presence or offline if not found.
  PresenceStatus _getCachedPresence(String sessionId, String userId) {
    return _presenceCache[sessionId]?[userId] ?? PresenceStatus.offline;
  }

  /// Update local cache.
  void _updateCache(String sessionId, String userId, PresenceStatus status) {
    if (!_presenceCache.containsKey(sessionId)) {
      _presenceCache[sessionId] = {};
    }
    _presenceCache[sessionId]![userId] = status;
  }

  /// Update user presence in a session.
  Future<void> updateSessionPresence(
    String sessionId,
    String userId,
    PresenceStatus status, {
    bool? isTyping,
  }) async {
    // Optimistic cache update
    _updateCache(sessionId, userId, status);

    try {
      final data = {
        'status': status.value,
        'lastChanged': FieldValue.serverTimestamp(),
        'userId': userId,
        if (isTyping != null) 'isTyping': isTyping,
      };

      await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('presence')
          .doc(userId)
          .set(data, SetOptions(merge: true));

      debugPrint(
        '[PresenceService] Updated presence for $userId: ${status.value}, typing: $isTyping',
      );
    } catch (e) {
      debugPrint('[PresenceService] Error updating presence: $e');
      // We keep the optimistic update in cache?
      // Yes, to allow "offline" presence to work locally for UI at least if needed,
      // though typically we want true server state.
      // But for fallback on read, we definitely want cache.
      rethrow;
    }
  }

  /// Set user as online in a session.
  Future<void> setOnline(String sessionId, String userId) async {
    await updateSessionPresence(sessionId, userId, PresenceStatus.online);
  }

  /// Set user as offline in a session.
  Future<void> setOffline(String sessionId, String userId) async {
    await updateSessionPresence(sessionId, userId, PresenceStatus.offline);
  }

  /// Set user as away (e.g., app backgrounded).
  Future<void> setAway(String sessionId, String userId) async {
    await updateSessionPresence(sessionId, userId, PresenceStatus.away);
  }

  /// Update typing status.
  Future<void> setTyping(String sessionId, String userId, bool isTyping) async {
    // We preserve current status ideally, but for simplicity assuming 'online' if typing
    // or just merge. merge: true is used in updateSessionPresence.
    await updateSessionPresence(
      sessionId,
      userId,
      PresenceStatus.online, // Make sure they are online if typing
      isTyping: isTyping,
    );
  }

  /// Listen to all online users in a session.
  Stream<List<String>> listenToSessionPresence(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('presence')
        .where('status', isEqualTo: 'online')
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs.map((doc) => doc.id).toList();
          // Update cache
          for (var userId in users) {
            _updateCache(sessionId, userId, PresenceStatus.online);
          }
          return users;
        })
        .onErrorReturnWith((e, stackTrace) {
          debugPrint(
            '[PresenceService] Stream error: $e. Returning cache fallback.',
          );
          final cached = _presenceCache[sessionId];
          if (cached != null) {
            return cached.entries
                .where((e) => e.value == PresenceStatus.online)
                .map((e) => e.key)
                .toList();
          }
          return <String>[];
        });
  }

  /// Listen to all presence statuses in a session.
  Stream<List<UserPresence>> listenToAllPresence(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('presence')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => UserPresence.fromFirestore(doc))
              .toList();

          // Update cache
          for (var p in list) {
            _updateCache(sessionId, p.userId, p.status);
          }
          return list;
        })
        .onErrorReturnWith((e, stackTrace) {
          debugPrint(
            '[PresenceService] AllPresence stream error: $e. Returning cache fallback.',
          );
          final cached = _presenceCache[sessionId];
          if (cached != null) {
            return cached.entries.map((e) {
              return UserPresence(
                userId: e.key,
                status: e.value,
                lastChanged: DateTime.now(), // Estimate
              );
            }).toList();
          }
          return <UserPresence>[];
        });
  }

  /// Get current presence for a user in a session.
  Future<PresenceStatus> getUserPresence(
    String sessionId,
    String userId,
  ) async {
    try {
      final doc = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('presence')
          .doc(userId)
          .get();

      if (!doc.exists) return PresenceStatus.offline;

      final status = PresenceStatusExtension.fromString(
        doc.data()?['status'] ?? 'offline',
      );
      _updateCache(sessionId, userId, status);
      return status;
    } catch (e) {
      debugPrint('[PresenceService] Error getting presence: $e');
      return _getCachedPresence(sessionId, userId);
    }
  }

  /// Remove user presence from a session.
  Future<void> removePresence(String sessionId, String userId) async {
    try {
      await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('presence')
          .doc(userId)
          .delete();

      if (_presenceCache.containsKey(sessionId)) {
        _presenceCache[sessionId]!.remove(userId);
      }
    } catch (e) {
      debugPrint('[PresenceService] Error removing presence: $e');
    }
  }

  /// Get count of online users in a session.
  Future<int> getOnlineCount(String sessionId) async {
    try {
      final snapshot = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('presence')
          .where('status', isEqualTo: 'online')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('[PresenceService] Error getting online count: $e');
      final cached = _presenceCache[sessionId];
      if (cached != null) {
        return cached.values.where((s) => s == PresenceStatus.online).length;
      }
      return 0;
    }
  }
}

/// Presence service provider.
final presenceServiceProvider = Provider<PresenceService>((ref) {
  return PresenceService(ref.watch(firestoreProvider));
});

/// Session online users stream provider.
final sessionOnlineUsersProvider = StreamProvider.family<List<String>, String>((
  ref,
  sessionId,
) {
  return ref.watch(presenceServiceProvider).listenToSessionPresence(sessionId);
});

/// All session presence stream provider.
final sessionPresenceProvider =
    StreamProvider.family<List<UserPresence>, String>((ref, sessionId) {
      return ref.watch(presenceServiceProvider).listenToAllPresence(sessionId);
    });
