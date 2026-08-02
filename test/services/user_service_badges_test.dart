import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/services/user_service.dart';

/// Adds `count` completed sessions for [userId], the first
/// [buddyCount] of which have a second participant.
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

void main() {
  late FakeFirebaseFirestore firestore;
  late UserService service;
  const userId = 'user-1';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = UserService(firestore);
  });

  group('calculateUserStreak buddy derivation', () {
    test('counts multi-participant sessions from the same read', () async {
      await _seedSessions(firestore, userId, count: 5, buddyCount: 3);

      final stats = await service.calculateUserStreak(userId);

      expect(stats.totalWorkouts, 5);
      expect(stats.buddyWorkouts, 3);
    });

    test('counts zero buddy workouts when every session was solo', () async {
      await _seedSessions(firestore, userId, count: 4, buddyCount: 0);

      final stats = await service.calculateUserStreak(userId);

      expect(stats.totalWorkouts, 4);
      expect(stats.buddyWorkouts, 0);
    });

    test('tolerates a session document with no participants field', () async {
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

    test('awards social_butterfly from derived stats, not a second scan', () async {
      // 10 buddy sessions is the social_butterfly threshold.
      await _seedSessions(firestore, userId, count: 12, buddyCount: 10);
      await firestore.collection('sessions').doc('session-1').set({
        'participants': [userId, 'buddy-x'],
        'status': 'completed',
        'startedAt': Timestamp.fromDate(DateTime(2026, 2, 1, 12)),
      });

      final unlocked = await service.checkAndAwardBadges(userId, 'session-1');

      expect(unlocked, contains('social_butterfly'));
    });

    test('does not award social_butterfly below the threshold', () async {
      await _seedSessions(firestore, userId, count: 12, buddyCount: 4);
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
      await _seedSessions(firestore, userId, count: 50, buddyCount: 0);
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
      await firestore.collection('users').doc(userId).set({
        'badges': <String>['early_bird'],
      });
      await _seedSessions(firestore, userId, count: 3, buddyCount: 0);
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
