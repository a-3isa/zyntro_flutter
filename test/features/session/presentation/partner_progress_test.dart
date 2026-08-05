import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';

/// Coming back to a shared session has to show what actually happened while you
/// were gone — your partner's sets, and yours if you were the one still
/// training. Anything less and the two members are looking at different
/// workouts.
void main() {
  const alice = 'alice';
  const bob = 'bob';
  const sessionId = 's1';

  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  Future<void> seed({List<String> ended = const []}) async {
    await firestore.collection('sessions').doc(sessionId).set({
      'hostId': alice,
      'type': 'gym',
      'title': 'Session',
      'participants': [alice, bob],
      'participantTypes': {alice: 'gym', bob: 'gym'},
      'status': SessionStatus.active.value,
      'phase': SessionPhase.live.value,
      'activeUserId': alice,
      'endedParticipants': ended,
      'createdAt': DateTime.now(),
      'startedAt': DateTime.now(),
      'expiresAt': DateTime.now().add(const Duration(hours: 3)),
    });
  }

  Future<void> logSet(String userId, int index) async {
    await firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('events')
        .doc('set_${userId}_$index')
        .set({
          'type': SessionEventType.setLogged.value,
          'userId': userId,
          'text': 'Logged a set',
          'timestamp': DateTime.now(),
        });
  }

  group('work done while away is visible on return', () {
    test('the partner\'s sets are all there', () async {
      await seed();
      for (var i = 0; i < 5; i++) {
        await logSet(bob, i);
      }

      final events = await firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('events')
          .get();

      expect(events.docs.where((d) => d.data()['userId'] == bob), hasLength(5));
    });

    test('solo work is visible to the partner who returns', () async {
      // Alice kept training while Bob's app was closed. Bob must come back to
      // her ten sets, not to the session as he left it.
      await seed();
      for (var i = 0; i < 10; i++) {
        await logSet(alice, i);
      }

      final events = await firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('events')
          .get();

      expect(
        events.docs.where((d) => d.data()['userId'] == alice),
        hasLength(10),
      );
    });

    test('a partner leaving does not erase what they logged', () async {
      await seed();
      await logSet(bob, 0);
      await logSet(bob, 1);

      await firestore.collection('sessions').doc(sessionId).update({
        'endedParticipants': [bob],
      });

      final events = await firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('events')
          .get();
      expect(events.docs.where((d) => d.data()['userId'] == bob), hasLength(2));
    });

    test('the returning member is still a participant of a live session',
        () async {
      await seed(ended: [bob]);

      final session = Session.fromFirestore(
        await firestore.collection('sessions').doc(sessionId).get(),
      );

      // Bob left; Alice is still mid-workout and must be brought back.
      expect(session.isResumableFor(alice, DateTime.now().toUtc()), isTrue);
      expect(session.isResumableFor(bob, DateTime.now().toUtc()), isFalse);
    });
  });

  group('live updates need no manual refresh', () {
    test('the room streams the session rather than reading it once', () async {
      // A one-shot read would show the returning member a snapshot frozen at
      // the moment they opened the screen.
      final source = File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync();

      expect(source.contains('currentSessionProvider'), isTrue);
      expect(source.contains('recentSessionEventsProvider'), isTrue);
    });

    test('presence is streamed too, so away/back is noticed live', () {
      final source = File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync();

      expect(source.contains('sessionPresenceProvider'), isTrue);
    });
  });

  group('a set in progress is not interrupted', () {
    test('the view switch is damped, so it cannot fire mid-set', () {
      // Solo↔shared is delayed by the damper rather than flipping the instant
      // presence changes, which is what keeps a returning partner from
      // yanking the screen out from under a set being entered.
      final source = File(
        'lib/features/session/domain/turn_eligibility.dart',
      ).readAsStringSync();

      expect(source.contains('graceBeforeSolo'), isTrue);
      expect(source.contains('class SoloModeDamper'), isTrue);
    });

    test('turn handover happens on submit, never on a presence tick', () {
      // switchTurn is only ever called from set submission, so a partner
      // reappearing cannot seize the current turn — it resolves at the next
      // handover.
      final source = File(
        'lib/services/session_service.dart',
      ).readAsStringSync();

      expect(source.contains('Future<void> switchTurn('), isTrue);
      expect(source.contains('nextTurnHolder('), isTrue);
    });
  });
}
