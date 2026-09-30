import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feed_cache_service.dart';

/// Local privacy consent for analytics / crash reporting (Z-PRV-002).
///
/// Defaults on for shipping builds (matches prior behavior). Users can opt out
/// from Privacy settings; collection flags are applied immediately.
class PrivacyConsentService {
  PrivacyConsentService(this._prefs);

  static const analyticsKey = 'privacy_consent_analytics';
  static const crashlyticsKey = 'privacy_consent_crashlytics';

  final SharedPreferences _prefs;

  bool get analyticsEnabled => _prefs.getBool(analyticsKey) ?? true;

  bool get crashlyticsEnabled => _prefs.getBool(crashlyticsKey) ?? true;

  Future<void> applyToSdks() async {
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
        analyticsEnabled && !kDebugMode,
      );
    } catch (e) {
      debugPrint('[PrivacyConsent] analytics flag failed: $e');
    }
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        crashlyticsEnabled && !kDebugMode,
      );
    } catch (e) {
      debugPrint('[PrivacyConsent] crashlytics flag failed: $e');
    }
  }

  Future<void> setAnalyticsEnabled(bool enabled) async {
    await _prefs.setBool(analyticsKey, enabled);
    await applyToSdks();
  }

  Future<void> setCrashlyticsEnabled(bool enabled) async {
    await _prefs.setBool(crashlyticsKey, enabled);
    await applyToSdks();
  }
}

final privacyConsentServiceProvider = Provider<PrivacyConsentService>((ref) {
  return PrivacyConsentService(ref.watch(sharedPreferencesProvider));
});
