import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zyntro_flutter/core/auth/sign_out_cleanup.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/services/feed_cache_service.dart';
import 'package:zyntro_flutter/services/profile_cache_service.dart';
import 'package:zyntro_flutter/utils/offline_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late SharedPreferences prefs;
  var analyticsReset = false;
  var crashlyticsCleared = false;
  var firestoreCleared = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'zyntro_feed_cache': '{"posts":[],"cachedAt":"2026-01-01T00:00:00.000Z"}',
      'zyntro_profile_cache_alice': '{"id":"alice"}',
      'zyntro_workout_history_alice': '[]',
    });
    prefs = await SharedPreferences.getInstance();
    final firestore = FakeFirebaseFirestore();
    analyticsReset = false;
    crashlyticsCleared = false;
    firestoreCleared = false;

    container = ProviderContainer(
      overrides: [
        authFirestoreProvider.overrideWithValue(firestore),
        feedCacheServiceProvider.overrideWithValue(FeedCacheService(prefs)),
        profileCacheServiceProvider.overrideWithValue(
          ProfileCacheService(prefs),
        ),
      ],
    );

    await container.read(offlineManagerProvider).queueOperation(
          'session_event',
          {'sessionId': 's1'},
        );
  });

  tearDown(() => container.dispose());

  test('clears feed, profile, offline queue, and identity hooks', () async {
    final cleanup = container.read(signOutCleanupProvider)
      ..resetAnalytics = () async {
        analyticsReset = true;
      }
      ..clearCrashlyticsUser = () async {
        crashlyticsCleared = true;
      }
      ..clearFirestorePersistence = () async {
        firestoreCleared = true;
      };

    expect(prefs.containsKey('zyntro_feed_cache'), isTrue);
    expect(prefs.containsKey('zyntro_profile_cache_alice'), isTrue);
    expect(await container.read(offlineManagerProvider).getQueueCount(), 1);

    await cleanup.run(userId: 'alice');

    expect(prefs.containsKey('zyntro_feed_cache'), isFalse);
    expect(prefs.containsKey('zyntro_profile_cache_alice'), isFalse);
    expect(prefs.containsKey('zyntro_workout_history_alice'), isFalse);
    expect(await container.read(offlineManagerProvider).getQueueCount(), 0);
    expect(analyticsReset, isTrue);
    expect(crashlyticsCleared, isTrue);
    expect(firestoreCleared, isTrue);
  });
}
