import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/feed_cache_service.dart';
import '../../services/profile_cache_service.dart';
import '../../services/user_cache_service.dart';
import '../../utils/offline_manager.dart';

/// Clears device-local session residue on sign-out (Z-AUTH-003 / Z-DATA-003).
///
/// Runs before Firebase Auth sign-out so SharedPreferences / memory caches and
/// the offline queue cannot bleed into the next account. Analytics and
/// Crashlytics identity are reset so events are not attributed across users.
///
/// Firestore SDK persistence: FlutterFire keeps a terminated singleton, so a
/// full `terminate()` + `clearPersistence()` would brick subsequent reads until
/// process restart. We instead drop all app-owned caches (the durable PII
/// surfaces) and best-effort clear Firestore persistence when the SDK allows
/// it (typically only early in app lifetime / tests).
class SignOutCleanup {
  SignOutCleanup(this._ref);

  final Ref _ref;

  /// Optional hooks for unit tests (defaults call Firebase Analytics/Crashlytics).
  Future<void> Function()? resetAnalytics;
  Future<void> Function()? clearCrashlyticsUser;
  Future<void> Function()? clearFirestorePersistence;

  Future<void> run({String? userId}) async {
    try {
      await _ref.read(feedCacheServiceProvider).clearCache();
    } catch (e, st) {
      debugPrint('[SignOutCleanup] feed cache: $e\n$st');
    }

    if (userId != null) {
      try {
        await _ref.read(profileCacheServiceProvider).clearCache(userId);
      } catch (e, st) {
        debugPrint('[SignOutCleanup] profile cache: $e\n$st');
      }
    }

    try {
      _ref.read(userCacheServiceProvider).clearCache();
    } catch (e, st) {
      debugPrint('[SignOutCleanup] user cache: $e\n$st');
    }

    try {
      await _ref.read(offlineManagerProvider).clearQueue();
      _ref.read(offlineManagerProvider).bindUser(null);
    } catch (e, st) {
      debugPrint('[SignOutCleanup] offline queue: $e\n$st');
    }

    try {
      await (resetAnalytics ?? _defaultResetAnalytics)();
    } catch (e, st) {
      debugPrint('[SignOutCleanup] analytics: $e\n$st');
    }

    try {
      await (clearCrashlyticsUser ?? _defaultClearCrashlyticsUser)();
    } catch (e, st) {
      debugPrint('[SignOutCleanup] crashlytics: $e\n$st');
    }

    try {
      await (clearFirestorePersistence ?? _defaultClearFirestorePersistence)();
    } catch (e, st) {
      debugPrint('[SignOutCleanup] firestore persistence: $e\n$st');
    }
  }

  static Future<void> _defaultResetAnalytics() async {
    await FirebaseAnalytics.instance.setUserId(id: null);
    await FirebaseAnalytics.instance.resetAnalyticsData();
  }

  static Future<void> _defaultClearCrashlyticsUser() async {
    await FirebaseCrashlytics.instance.setUserIdentifier('');
  }

  /// Best-effort. Succeeds only when Firestore is not actively started with
  /// listeners (e.g. tests). Never calls [FirebaseFirestore.terminate] in
  /// production paths — that permanently disables the FlutterFire singleton.
  static Future<void> _defaultClearFirestorePersistence() async {
    try {
      await FirebaseFirestore.instance.clearPersistence();
    } catch (_) {
      // Expected while the app has an active Firestore client.
    }
  }
}

final signOutCleanupProvider = Provider<SignOutCleanup>((ref) {
  return SignOutCleanup(ref);
});
