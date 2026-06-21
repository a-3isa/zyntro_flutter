import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/models.dart';
import '../core/constants/constants.dart';
import 'feed_cache_service.dart';

class ProfileCacheService {
  static String _profileKey(String userId) => 'zyntro_profile_cache_$userId';
  static String _historyKey(String userId) =>
      'zyntro_workout_history_$userId';

  final SharedPreferences _prefs;
  ProfileCacheService(this._prefs);

  User? readProfile(String userId) {
    try {
      final raw = _prefs.getString(_profileKey(userId));
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _userFromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeProfile(String userId, User profile) async {
    await _prefs.setString(_profileKey(userId), jsonEncode(_userToMap(profile)));
  }

  List<Map<String, dynamic>> readWorkoutHistory(String userId) {
    try {
      final raw = _prefs.getString(_historyKey(userId));
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> writeWorkoutHistory(
    String userId,
    List<Map<String, dynamic>> sessions,
  ) async {
    await _prefs.setString(_historyKey(userId), jsonEncode(sessions));
  }

  Future<void> clearCache(String userId) async {
    await _prefs.remove(_profileKey(userId));
    await _prefs.remove(_historyKey(userId));
  }

  Map<String, dynamic> _userToMap(User u) => {
        'id': u.id,
        'displayName': u.displayName,
        'username': u.username,
        'photoURL': u.photoURL,
        'isPrivate': u.isPrivate,
        'workoutPreference': u.workoutPreference.value,
        'beginnerFlag': u.beginnerFlag,
        'avatarConfig': u.avatarConfig,
        'createdAt': u.createdAt.toIso8601String(),
        'updatedAt': u.updatedAt.toIso8601String(),
        'lastActive': u.lastActive?.toIso8601String(),
        'workoutScore': u.workoutScore,
        'totalWorkouts': u.totalWorkouts,
        'hasGlobalLeaderboardAccess': u.hasGlobalLeaderboardAccess,
        'globalAccessGrantedAt': u.globalAccessGrantedAt?.toIso8601String(),
        'isModerator': u.isModerator,
        'isBanned': u.isBanned,
        'bannedUntil': u.bannedUntil?.toIso8601String(),
        'banReason': u.banReason,
        'buddyIds': u.buddyIds,
      };

  User _userFromMap(Map<String, dynamic> m) => User(
        id: m['id'] as String,
        displayName: m['displayName'] as String,
        username: m['username'] as String?,
        photoURL: m['photoURL'] as String?,
        isPrivate: m['isPrivate'] as bool? ?? false,
        workoutPreference: WorkoutType.fromString(
            m['workoutPreference'] as String? ?? 'both'),
        beginnerFlag: m['beginnerFlag'] as bool? ?? false,
        avatarConfig: m['avatarConfig'] as String?,
        createdAt: DateTime.parse(m['createdAt'] as String),
        updatedAt: DateTime.parse(m['updatedAt'] as String),
        lastActive: m['lastActive'] != null
            ? DateTime.parse(m['lastActive'] as String)
            : null,
        workoutScore: m['workoutScore'] as int? ?? 0,
        totalWorkouts: m['totalWorkouts'] as int? ?? 0,
        hasGlobalLeaderboardAccess:
            m['hasGlobalLeaderboardAccess'] as bool? ?? false,
        globalAccessGrantedAt: m['globalAccessGrantedAt'] != null
            ? DateTime.parse(m['globalAccessGrantedAt'] as String)
            : null,
        isModerator: m['isModerator'] as bool? ?? false,
        isBanned: m['isBanned'] as bool? ?? false,
        bannedUntil: m['bannedUntil'] != null
            ? DateTime.parse(m['bannedUntil'] as String)
            : null,
        banReason: m['banReason'] as String?,
        buddyIds: (m['buddyIds'] as List<dynamic>?)?.cast<String>(),
      );
}

final profileCacheServiceProvider = Provider<ProfileCacheService>((ref) {
  return ProfileCacheService(ref.watch(sharedPreferencesProvider));
});
