import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../exceptions/auth_data_exception.dart';
import '../models/auth_user_model.dart';

class AuthLocalDataSource {
  static const String _cachedUserKey = 'auth.cached_user';
  static const String _cachedUserAtKey = 'auth.cached_user_at';

  const AuthLocalDataSource();

  Future<void> cacheUser(AuthUserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedUserKey, user.toEncodedJson());
      await prefs.setInt(
        _cachedUserAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      throw AuthDataException.cache('Failed to persist auth cache.');
    }
  }

  // TTL removed intentionally — see 005-profile-auth-social-fixes.
  // To roll back: re-add static const Duration _cacheTtl = Duration(minutes: 30);
  // and restore the age-check block before the fromEncodedJson call.
  Future<AuthUserModel?> getCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_cachedUserKey);
      final cachedAt = prefs.getInt(_cachedUserAtKey);

      if (encoded == null || cachedAt == null) {
        FirebaseAnalytics.instance.logEvent(name: 'auth_startup_cache_miss');
        return null;
      }

      FirebaseAnalytics.instance.logEvent(name: 'auth_startup_cache_hit');
      return AuthUserModel.fromEncodedJson(encoded);
    } catch (_) {
      throw AuthDataException.cache('Failed to read auth cache.');
    }
  }

  Future<void> clearCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedUserKey);
      await prefs.remove(_cachedUserAtKey);
      FirebaseAnalytics.instance.logEvent(
        name: 'auth_startup_sign_in_required',
      );
    } catch (_) {
      throw AuthDataException.cache('Failed to clear auth cache.');
    }
  }
}
