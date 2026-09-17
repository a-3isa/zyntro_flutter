import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/services/matchmaking_service.dart';
import 'package:zyntro_flutter/services/session_service.dart';

final _testRefProvider = Provider<Ref>((ref) => ref);

void main() {
  late FakeFirebaseFirestore firestore;
  late MatchmakingService service;
  late ProviderContainer container;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    container = ProviderContainer(overrides: [_testRefProvider]);
    service = MatchmakingService(
      firestore,
      SessionService(firestore, container.read(_testRefProvider)),
    );
  });

  tearDown(() => container.dispose());

  Future<List<Map<String, dynamic>>> queueEntries() async {
    final snap = await firestore.collection('matchmaking_queue').get();
    return snap.docs.map((d) => d.data()).toList();
  }

  group('joinQueue with nobody waiting', () {
    test('enqueues the user and reports waiting', () async {
      final outcome = await service.joinQueue(
        userId: 'alice',
        workoutType: WorkoutType.gym,
      );

      expect(outcome, isA<WaitingForMatch>());
      expect((outcome as WaitingForMatch).queueDocId, isNotEmpty);
    });

    test('writes a discoverable waiting entry', () async {
      await service.joinQueue(userId: 'alice', workoutType: WorkoutType.gym);

      final entries = await queueEntries();
      expect(entries, hasLength(1));
      expect(entries.single['userId'], 'alice');
      expect(entries.single['workoutType'], 'gym');
      expect(entries.single['status'], 'waiting');
    });

    test('records the workout type it was asked for', () async {
      await service.joinQueue(
        userId: 'alice',
        workoutType: WorkoutType.running,
      );

      final entries = await queueEntries();
      expect(entries.single['workoutType'], 'running');
    });
  });

  group('joinQueue does not match the wrong partner', () {
    test('ignores a waiter doing a different workout type', () async {
      await firestore.collection('matchmaking_queue').add({
        'userId': 'bob',
        'workoutType': WorkoutType.running.value,
        'status': 'waiting',
      });

      final outcome = await service.joinQueue(
        userId: 'alice',
        workoutType: WorkoutType.gym,
      );

      expect(
        outcome,
        isA<WaitingForMatch>(),
        reason: 'a runner must not be matched into a gym session',
      );
    });

    test('ignores an entry that is no longer waiting', () async {
      await firestore.collection('matchmaking_queue').add({
        'userId': 'bob',
        'workoutType': WorkoutType.gym.value,
        'status': 'matched',
      });

      final outcome = await service.joinQueue(
        userId: 'alice',
        workoutType: WorkoutType.gym,
      );

      expect(outcome, isA<WaitingForMatch>());
    });

    test('never matches a user with themselves', () async {
      // Two entries for the same person — a stale one plus the new join.
      await firestore.collection('matchmaking_queue').add({
        'userId': 'alice',
        'workoutType': WorkoutType.gym.value,
        'status': 'waiting',
      });

      final outcome = await service.joinQueue(
        userId: 'alice',
        workoutType: WorkoutType.gym,
      );

      expect(
        outcome,
        isA<WaitingForMatch>(),
        reason: 'self-matching would create a session with one real person',
      );
    });

    test('skips a partner the caller has blocked', () async {
      await firestore.collection('matchmaking_queue').add({
        'userId': 'bob',
        'workoutType': WorkoutType.gym.value,
        'status': 'waiting',
      });
      await firestore.collection('blocks').doc('alice_bob').set({
        'blockerId': 'alice',
        'blockedUserId': 'bob',
      });

      final outcome = await service.joinQueue(
        userId: 'alice',
        workoutType: WorkoutType.gym,
      );

      expect(
        outcome,
        isA<WaitingForMatch>(),
        reason: 'blocked partners must not be claimed (Z-RT-003)',
      );
      final bob = await firestore
          .collection('matchmaking_queue')
          .where('userId', isEqualTo: 'bob')
          .get();
      expect(bob.docs.single.data()['status'], 'waiting');
    });
  });

  group('cancelQueue', () {
    test('removes the entry', () async {
      final outcome = await service.joinQueue(
        userId: 'alice',
        workoutType: WorkoutType.gym,
      ) as WaitingForMatch;

      await service.cancelQueue(outcome.queueDocId);

      expect(await queueEntries(), isEmpty);
    });

    test('is safe to call for an id that is already gone', () async {
      await expectLater(service.cancelQueue('never-existed'), completes);
    });

    test('leaves other people in the queue alone', () async {
      await firestore.collection('matchmaking_queue').doc('bob-entry').set({
        'userId': 'bob',
        'workoutType': WorkoutType.running.value,
        'status': 'waiting',
      });
      final outcome = await service.joinQueue(
        userId: 'alice',
        workoutType: WorkoutType.gym,
      ) as WaitingForMatch;

      await service.cancelQueue(outcome.queueDocId);

      final entries = await queueEntries();
      expect(entries, hasLength(1));
      expect(entries.single['userId'], 'bob');
    });
  });

  group('listenToQueueEntry', () {
    test('emits the entry as it stands', () async {
      await firestore.collection('matchmaking_queue').doc('entry').set({
        'userId': 'alice',
        'status': 'waiting',
      });

      final first = await service.listenToQueueEntry('entry').first;

      expect(first?['status'], 'waiting');
    });

    test('emits null for an entry that does not exist', () async {
      expect(await service.listenToQueueEntry('missing').first, isNull);
    });

    test('emits again when the entry is matched', () async {
      final doc = firestore.collection('matchmaking_queue').doc('entry');
      await doc.set({'userId': 'alice', 'status': 'waiting'});

      final future = service
          .listenToQueueEntry('entry')
          .firstWhere((e) => e?['status'] == 'matched');

      await doc.update({'status': 'matched', 'sessionId': 'session-1'});

      final matched = await future;
      expect(matched?['sessionId'], 'session-1');
    });
  });
}
