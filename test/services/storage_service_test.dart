import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zyntro_flutter/services/storage_service.dart';

/// StorageService touches FirebaseStorage only inside its upload methods,
/// which need a live plugin. The preference surface tested here never reaches
/// it, so an unstubbed mock is enough to construct the service.
class MockFirebaseStorage extends Mock implements FirebaseStorage {}

Future<StorageService> buildService([Map<String, Object>? initial]) async {
  SharedPreferences.setMockInitialValues(initial ?? {});
  final service = StorageService(MockFirebaseStorage());
  await service.init();
  return service;
}

void main() {
  late StorageService service;

  setUp(() async {
    service = await buildService();
  });

  group('hasSeenOnboarding', () {
    test('defaults to false for a fresh install', () {
      expect(service.hasSeenOnboarding, isFalse);
    });

    test('persists once set', () async {
      await service.setHasSeenOnboarding(true);

      expect(service.hasSeenOnboarding, isTrue);
    });

    test('can be turned back off', () async {
      await service.setHasSeenOnboarding(true);
      await service.setHasSeenOnboarding(false);

      expect(service.hasSeenOnboarding, isFalse);
    });

    test('survives a new service instance over the same store', () async {
      await service.setHasSeenOnboarding(true);

      final reopened = StorageService(MockFirebaseStorage());
      await reopened.init();

      expect(reopened.hasSeenOnboarding, isTrue);
    });
  });

  group('workoutPreference', () {
    test('is null until the user picks one', () {
      expect(service.workoutPreference, isNull);
    });

    test('round-trips the stored value', () async {
      await service.setWorkoutPreference('gym');

      expect(service.workoutPreference, 'gym');
    });

    test('the latest choice wins', () async {
      await service.setWorkoutPreference('gym');
      await service.setWorkoutPreference('running');

      expect(service.workoutPreference, 'running');
    });
  });

  group('clear', () {
    test('drops every stored preference', () async {
      await service.setHasSeenOnboarding(true);
      await service.setWorkoutPreference('gym');

      await service.clear();

      expect(service.hasSeenOnboarding, isFalse);
      expect(service.workoutPreference, isNull);
    });

    test('is safe on an already-empty store', () async {
      await expectLater(service.clear(), completes);
    });
  });

  group('reading values that were already on disk', () {
    test('picks up preferences written before this run', () async {
      final restored = await buildService({
        'has_seen_onboarding': true,
        'workout_preference': 'swimming',
      });

      expect(restored.hasSeenOnboarding, isTrue);
      expect(restored.workoutPreference, 'swimming');
    });

    // Not tested: a wrongly typed stored value. SharedPreferences.getBool
    // throws on one, and the getter does not guard against it — but the key is
    // only ever written by setHasSeenOnboarding(bool), so the state is
    // unreachable. Adding a guard would be defending against nothing.
  });
}
