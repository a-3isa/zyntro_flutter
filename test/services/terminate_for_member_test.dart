import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/services/session_service.dart';

/// Terminating is per-member. The defect this guards against is one member
/// walking out and ending their partner's workout with them — losing sets the
/// partner had already logged and had no say in.
void main() {
  const alice = 'alice';
  const bob = 'bob';
  const sessionId = 's1';

  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  late SessionService service;

  Future<void> seedSession({
    List<String> participants = const [alice, bob],
    List<String> endedParticipants = const [],
    String? activeUserId,
  }) async {
    // endSession writes score and streak counters onto the participants, so the
    // last-member-out path needs these to exist.
    for (final p in participants) {
      await firestore.collection('users').doc(p).set({
        'displayName': p,
        'workoutScore': 0,
        'totalWorkouts': 0,
      });
    }
    await firestore.collection('sessions').doc(sessionId).set({
      'hostId': alice,
      'type': WorkoutType.gym.value,
      'title': 'Session',
      'participants': participants,
      'participantTypes': {
        for (final p in participants) p: WorkoutType.gym.value,
      },
      'status': SessionStatus.active.value,
      'phase': SessionPhase.live.value,
      'activeUserId': activeUserId ?? participants.first,
      'endedParticipants': endedParticipants,
      'createdAt': DateTime.now(),
      'startedAt': DateTime.now(),
      'expiresAt': DateTime.now().add(const Duration(hours: 3)),
    });
  }

  Future<Map<String, dynamic>?> readSession() async =>
      (await firestore.collection('sessions').doc(sessionId).get()).data();

  setUp(() {
    firestore = FakeFirebaseFirestore();
    container = ProviderContainer(
      overrides: [authFirestoreProvider.overrideWithValue(firestore)],
    );
    service = container.read(sessionServiceProvider);
  });

  tearDown(() => container.dispose());

  group('one member leaving a shared session', () {
    test('records only that member as ended', () async {
      await seedSession();

      await service.terminateForMember(sessionId, alice);

      final data = await readSession();
      expect(data?['endedParticipants'], [alice]);
    });

    test('leaves the session live for the partner', () async {
      await seedSession();

      await service.terminateForMember(sessionId, alice);

      // The whole point: Bob is still mid-workout and must not have it ended
      // for him.
      final data = await readSession();
      expect(data?['status'], SessionStatus.active.value);
      expect(data?['phase'], SessionPhase.live.value);
    });

    test('never removes anyone from participants', () async {
      // Read access is gated on `participants`, so dropping the leaver would
      // revoke their access to their own recorded work.
      await seedSession();

      await service.terminateForMember(sessionId, alice);

      expect(await readSession().then((d) => d?['participants']), [alice, bob]);
    });

    test('hands the turn on if the leaver was holding it', () async {
      await seedSession(activeUserId: alice);

      await service.terminateForMember(sessionId, alice);

      // Otherwise the session stalls forever on someone who has gone.
      expect(await readSession().then((d) => d?['activeUserId']), bob);
    });

    test('leaves the turn alone if the leaver was not holding it', () async {
      await seedSession(activeUserId: bob);

      await service.terminateForMember(sessionId, alice);

      expect(await readSession().then((d) => d?['activeUserId']), bob);
    });

    test('writes a leave event', () async {
      await seedSession();

      await service.terminateForMember(sessionId, alice);

      final events = await firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('events')
          .get();
      expect(
        events.docs.map((d) => d.data()['type']),
        contains(SessionEventType.leave.value),
      );
    });

    test('stamps activity so the session does not expire on the partner',
        () async {
      await seedSession();

      await service.terminateForMember(sessionId, alice);

      expect(await readSession().then((d) => d?['expiresAt']), isNotNull);
    });
  });

  group('the last member out', () {
    test('completes the session properly', () async {
      await seedSession(participants: [alice]);

      await service.terminateForMember(sessionId, alice);

      // Delegates to endSession, so scoring, streaks and workout logging all
      // run exactly as they did before this feature.
      expect(
        await readSession().then((d) => d?['status']),
        SessionStatus.completed.value,
      );
    });

    test('completes it when the partner had already left', () async {
      await seedSession(endedParticipants: [bob]);

      await service.terminateForMember(sessionId, alice);

      expect(
        await readSession().then((d) => d?['status']),
        SessionStatus.completed.value,
      );
    });
  });

  group('guards', () {
    test('terminating twice is a no-op', () async {
      await seedSession(endedParticipants: [alice]);

      await service.terminateForMember(sessionId, alice);

      // Must not tip a two-person session into "everyone has left" on a double
      // tap or a retry.
      final data = await readSession();
      expect(data?['endedParticipants'], [alice]);
      expect(data?['status'], SessionStatus.active.value);
    });

    test('a non-participant cannot terminate', () async {
      await seedSession();

      await service.terminateForMember(sessionId, 'mallory');

      expect(await readSession().then((d) => d?['endedParticipants']), isEmpty);
    });

    test('a missing session is survivable', () async {
      await expectLater(
        service.terminateForMember('does-not-exist', alice),
        completes,
      );
    });
  });
}
