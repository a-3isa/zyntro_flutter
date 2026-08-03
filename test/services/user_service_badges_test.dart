import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/features/session/domain/workout_streak.dart';
import 'package:zyntro_flutter/services/user_service.dart';

/// Adds `count` completed sessions for [userId], the first
/// [buddyCount] of which have a second participant.
///
/// This is the pre-counter shape: sessions exist but the user document carries
/// no streak counters, which is what a user looks like before their first
/// post-migration session end.
Future<void> _seedSessions(
  FakeFirebaseFirestore firestore,
  String userId, {
  required int count,
  required int buddyCount,
}) async {
  for (var i = 0; i < count; i++) {
    await firestore.collection('sessions').add({
      'participants': i < buddyCount ? [userId, 'buddy-$i'] : [userId],
      'status': 'completed',
      // Distinct days so streak math sees each session as its own workout day.
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1).add(Duration(days: i))),
    });
  }
}

/// Writes the maintained counters onto the user document, the way session end
/// does in production. `totalWorkouts` alone is not enough to look migrated —
/// `lastWorkoutDate` is what marks the counters as populated.
Future<void> _seedCounters(
  FakeFirebaseFirestore firestore,
  String userId, {
  required int totalWorkouts,
  required int buddyWorkouts,
  List<String> badges = const [],
}) {
  return firestore.collection('users').doc(userId).set({
    'badges': badges,
    'totalWorkouts': totalWorkouts,
    'buddyWorkouts': buddyWorkouts,
    'currentStreak': 1,
    'longestStreak': 1,
    'lastWorkoutDate': calendarDay(DateTime.now()),
    'weeklyWorkouts': 1,
    'weekStartDate': weekStartFor(DateTime.now()),
  });
}

void main() {
  late FakeFirebaseFirestore firestore;
  late UserService service;
  const userId = 'user-1';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = UserService(firestore);
  });

  group('calculateUserStreak from maintained counters', () {
    test('serves stats from the user document without scanning sessions', () async {
      await _seedCounters(
        firestore,
        userId,
        totalWorkouts: 42,
        buddyWorkouts: 17,
      );
      // No session documents exist at all: if the counters are being used, the
      // absence of history is irrelevant.
      final stats = await service.calculateUserStreak(userId);

      expect(stats.totalWorkouts, 42);
      expect(stats.buddyWorkouts, 17);
      expect(stats.currentStreak, 1);
    });

    test('reports a lapsed streak as zero without losing the record', () async {
      await firestore.collection('users').doc(userId).set({
        'totalWorkouts': 30,
        'currentStreak': 9,
        'longestStreak': 14,
        // Two days ago: too old to still count as an active streak.
        'lastWorkoutDate': calendarDay(
          DateTime.now().subtract(const Duration(days: 2)),
        ),
      });

      final stats = await service.calculateUserStreak(userId);

      expect(stats.currentStreak, 0);
      expect(stats.longestStreak, 14);
    });

    test('keeps a streak alive when the last workout was yesterday', () async {
      await firestore.collection('users').doc(userId).set({
        'totalWorkouts': 30,
        'currentStreak': 9,
        'longestStreak': 14,
        'lastWorkoutDate': calendarDay(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
      });

      expect((await service.calculateUserStreak(userId)).currentStreak, 9);
    });

    test('zeroes the weekly tally once the stored week has passed', () async {
      await firestore.collection('users').doc(userId).set({
        'totalWorkouts': 30,
        'lastWorkoutDate': calendarDay(DateTime.now()),
        'weeklyWorkouts': 6,
        'weekStartDate': weekStartFor(
          DateTime.now().subtract(const Duration(days: 14)),
        ),
      });

      expect((await service.calculateUserStreak(userId)).weeklyWorkouts, 0);
    });

    test('returns zeroes for a brand new user with no workouts', () async {
      await firestore.collection('users').doc(userId).set({'totalWorkouts': 0});

      final stats = await service.calculateUserStreak(userId);

      expect(stats.totalWorkouts, 0);
      expect(stats.currentStreak, 0);
      expect(stats.buddyWorkouts, 0);
    });
  });

  group('calculateUserStreak pre-counter fallback', () {
    test('scans history when a user has workouts but no counters', () async {
      // totalWorkouts > 0 with no lastWorkoutDate is exactly what a user
      // document written before the counters existed looks like.
      await firestore.collection('users').doc(userId).set({'totalWorkouts': 5});
      await _seedSessions(firestore, userId, count: 5, buddyCount: 3);

      final stats = await service.calculateUserStreak(userId);

      expect(stats.totalWorkouts, 5);
      expect(stats.buddyWorkouts, 3);
    });

    test('counts zero buddy workouts when every session was solo', () async {
      await firestore.collection('users').doc(userId).set({'totalWorkouts': 4});
      await _seedSessions(firestore, userId, count: 4, buddyCount: 0);

      final stats = await service.calculateUserStreak(userId);

      expect(stats.totalWorkouts, 4);
      expect(stats.buddyWorkouts, 0);
    });

    test('tolerates a session document with no createdAt field', () async {
      await firestore.collection('users').doc(userId).set({'totalWorkouts': 2});
      await firestore.collection('sessions').add({
        'participants': [userId],
        'status': 'completed',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      // A malformed document must not throw — badge checks run after every
      // session and a single bad row should not take the whole check down.
      await firestore.collection('sessions').add({
        'participants': [userId],
        'status': 'completed',
      });

      final stats = await service.calculateUserStreak(userId);

      expect(stats.buddyWorkouts, 0);
      expect(stats.totalWorkouts, 2);
    });
  });

  group('checkAndAwardBadges', () {
    setUp(() async {
      await firestore.collection('users').doc(userId).set({'badges': <String>[]});
    });

    test('awards social_butterfly from the counter, not a history scan', () async {
      // 10 buddy sessions is the social_butterfly threshold. No session history
      // is seeded, so this can only pass by reading the maintained counter.
      await _seedCounters(firestore, userId, totalWorkouts: 12, buddyWorkouts: 10);
      await firestore.collection('sessions').doc('session-1').set({
        'participants': [userId, 'buddy-x'],
        'status': 'completed',
        'startedAt': Timestamp.fromDate(DateTime(2026, 2, 1, 12)),
      });

      final unlocked = await service.checkAndAwardBadges(userId, 'session-1');

      expect(unlocked, contains('social_butterfly'));
    });

    test('does not award social_butterfly below the threshold', () async {
      await _seedCounters(firestore, userId, totalWorkouts: 12, buddyWorkouts: 4);
      await firestore.collection('sessions').doc('session-1').set({
        'participants': [userId, 'buddy-x'],
        'status': 'completed',
        'startedAt': Timestamp.fromDate(DateTime(2026, 2, 1, 12)),
      });

      final unlocked = await service.checkAndAwardBadges(userId, 'session-1');

      expect(unlocked, isNot(contains('social_butterfly')));
    });

    test('persists every unlocked badge in a single merged write', () async {
      // early_bird (before 7am) and iron_will (50 workouts) both trip here, so
      // the batched write has to carry more than one badge.
      await _seedCounters(firestore, userId, totalWorkouts: 50, buddyWorkouts: 0);
      await firestore.collection('sessions').doc('session-1').set({
        'participants': [userId],
        'status': 'completed',
        'startedAt': Timestamp.fromDate(DateTime(2026, 2, 1, 5)),
      });

      final unlocked = await service.checkAndAwardBadges(userId, 'session-1');

      expect(unlocked, containsAll(<String>['early_bird', 'iron_will']));

      final stored = await firestore.collection('users').doc(userId).get();
      final badges = (stored.data()?['badges'] as List).cast<String>();
      expect(badges, containsAll(unlocked));

      // Every awarded badge must carry an unlock date, or the profile UI has
      // a badge it cannot date.
      for (final badgeId in unlocked) {
        expect(stored.data()?['badgeUnlockDates']?[badgeId], isNotNull);
      }
    });

    test('awards supporter from a counted cheer aggregate', () async {
      await firestore.collection('sessions').doc('session-1').set({
        'participants': [userId],
        'status': 'completed',
        'startedAt': Timestamp.fromDate(DateTime(2026, 2, 1, 12)),
      });
      // supporter needs 5 cheers in this session.
      for (var i = 0; i < 5; i++) {
        await firestore
            .collection('sessions')
            .doc('session-1')
            .collection('events')
            .add({'userId': userId, 'type': 'cheer'});
      }

      final unlocked = await service.checkAndAwardBadges(userId, 'session-1');

      expect(unlocked, contains('supporter'));
    });

    test('does not award supporter below the cheer threshold', () async {
      await firestore.collection('sessions').doc('session-1').set({
        'participants': [userId],
        'status': 'completed',
        'startedAt': Timestamp.fromDate(DateTime(2026, 2, 1, 12)),
      });
      for (var i = 0; i < 4; i++) {
        await firestore
            .collection('sessions')
            .doc('session-1')
            .collection('events')
            .add({'userId': userId, 'type': 'cheer'});
      }

      final unlocked = await service.checkAndAwardBadges(userId, 'session-1');

      expect(unlocked, isNot(contains('supporter')));
    });

    test('counts only this user\'s cheer events', () async {
      await firestore.collection('sessions').doc('session-1').set({
        'participants': [userId],
        'status': 'completed',
        'startedAt': Timestamp.fromDate(DateTime(2026, 2, 1, 12)),
      });
      final events =
          firestore.collection('sessions').doc('session-1').collection('events');
      for (var i = 0; i < 3; i++) {
        await events.add({'userId': userId, 'type': 'cheer'});
      }
      // Another participant's cheers, and this user's non-cheer events, must
      // not push the badge over its threshold.
      for (var i = 0; i < 5; i++) {
        await events.add({'userId': 'someone-else', 'type': 'cheer'});
        await events.add({'userId': userId, 'type': 'setLogged'});
      }

      final unlocked = await service.checkAndAwardBadges(userId, 'session-1');

      expect(unlocked, isNot(contains('supporter')));
    });

    test('skips badges the user already holds', () async {
      await _seedCounters(
        firestore,
        userId,
        totalWorkouts: 3,
        buddyWorkouts: 0,
        badges: const ['early_bird'],
      );
      await firestore.collection('sessions').doc('session-1').set({
        'participants': [userId],
        'status': 'completed',
        'startedAt': Timestamp.fromDate(DateTime(2026, 2, 1, 5)),
      });

      final unlocked = await service.checkAndAwardBadges(userId, 'session-1');

      expect(unlocked, isNot(contains('early_bird')));
    });

    test('returns empty rather than throwing when the user doc is absent', () async {
      await firestore.collection('users').doc(userId).delete();

      // Must not throw: a badge check runs after session end and must never
      // fail the session that triggered it.
      await expectLater(
        service.checkAndAwardBadges('ghost-user', 'session-1'),
        completes,
      );
    });
  });
}
