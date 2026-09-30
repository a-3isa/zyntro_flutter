import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/services/profile_cache_service.dart';

User _makeUser(String id, {String displayName = 'Test User'}) => User(
      id: id,
      displayName: displayName,
      username: 'user_$id',
      photoURL: null,
      isPrivate: false,
      workoutPreference: WorkoutType.other,
      beginnerFlag: false,
      avatarConfig: null,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 2),
      lastActive: null,
      workoutScore: 0,
      totalWorkouts: 0,
      hasGlobalLeaderboardAccess: false,
      globalAccessGrantedAt: null,
      isModerator: false,
      isBanned: false,
      bannedUntil: null,
      banReason: null,
      buddyIds: null,
    );

List<Map<String, dynamic>> _makeHistory(int count) => List.generate(
      count,
      (i) => {
        'id': 'workout_$i',
        'userId': 'u1',
        'type': 'strength',
        'endedAt': DateTime(2025, 1, i + 1).toIso8601String(),
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileCacheService', () {
    late ProfileCacheService svc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      svc = ProfileCacheService(prefs);
    });

    // ── readProfile ──────────────────────────────────────────────────────────

    test('readProfile returns null when no cache', () {
      expect(svc.readProfile('u1'), isNull);
    });

    test('writeProfile then readProfile round-trips id and displayName',
        () async {
      await svc.writeProfile('u1', _makeUser('u1', displayName: 'Alice'));
      final result = svc.readProfile('u1');
      expect(result, isNotNull);
      expect(result!.id, 'u1');
      expect(result.displayName, 'Alice');
    });

    test('writeProfile then readProfile round-trips username and isPrivate',
        () async {
      final user = _makeUser('u1');
      await svc.writeProfile('u1', user);
      final result = svc.readProfile('u1');
      expect(result!.username, 'user_u1');
      expect(result.isPrivate, isFalse);
    });

    test('readProfile for different userId returns null when only u1 cached',
        () async {
      await svc.writeProfile('u1', _makeUser('u1'));
      expect(svc.readProfile('u2'), isNull);
    });

    test('writeProfile overwrites previous cache for same userId', () async {
      await svc.writeProfile('u1', _makeUser('u1', displayName: 'Before'));
      await svc.writeProfile('u1', _makeUser('u1', displayName: 'After'));
      final result = svc.readProfile('u1');
      expect(result!.displayName, 'After');
    });

    // ── readWorkoutHistory ───────────────────────────────────────────────────

    test('readWorkoutHistory returns [] when no cache', () {
      expect(svc.readWorkoutHistory('u1'), isEmpty);
    });

    test('writeWorkoutHistory then readWorkoutHistory round-trips', () async {
      final history = _makeHistory(3);
      await svc.writeWorkoutHistory('u1', history);
      final result = svc.readWorkoutHistory('u1');
      expect(result, hasLength(3));
      expect(result.first['id'], 'workout_0');
    });

    test('readWorkoutHistory for different userId returns []', () async {
      await svc.writeWorkoutHistory('u1', _makeHistory(2));
      expect(svc.readWorkoutHistory('u2'), isEmpty);
    });

    // ── clearCache ───────────────────────────────────────────────────────────

    test('clearCache removes profile and history for userId', () async {
      await svc.writeProfile('u1', _makeUser('u1'));
      await svc.writeWorkoutHistory('u1', _makeHistory(2));
      await svc.clearCache('u1');
      expect(svc.readProfile('u1'), isNull);
      expect(svc.readWorkoutHistory('u1'), isEmpty);
    });

    test('clearCache for u1 does not affect u2 cache', () async {
      await svc.writeProfile('u1', _makeUser('u1'));
      await svc.writeProfile('u2', _makeUser('u2', displayName: 'Bob'));
      await svc.clearCache('u1');
      expect(svc.readProfile('u1'), isNull);
      expect(svc.readProfile('u2')!.displayName, 'Bob');
    });
  });
}
