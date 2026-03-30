import 'package:shared_preferences/shared_preferences.dart';

import '../exceptions/auth_data_exception.dart';
import '../models/auth_user_model.dart';

class AuthLocalDataSource {
  static const String _cachedUserKey = 'auth.cached_user';
  static const String _cachedUserAtKey = 'auth.cached_user_at';
  static const Duration _cacheTtl = Duration(minutes: 30);

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

  Future<AuthUserModel?> getCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_cachedUserKey);
      final cachedAt = prefs.getInt(_cachedUserAtKey);

      if (encoded == null || cachedAt == null) {
        return null;
      }

      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(cachedAt),
      );

      if (age > _cacheTtl) {
        await clearCachedUser();
        return null;
      }

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
    } catch (_) {
      throw AuthDataException.cache('Failed to clear auth cache.');
    }
  }
}
