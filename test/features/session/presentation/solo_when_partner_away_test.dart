import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/session/domain/turn_eligibility.dart';
import 'package:zyntro_flutter/services/presence_service.dart';

/// The member who stayed must never be stuck waiting on a partner who closed
/// their app. These assert the rule that drives the view, plus a source
/// contract that the session room actually consults it — a correct predicate
/// nothing calls would leave the original defect in place.
void main() {
  const alice = 'alice';
  const bob = 'bob';
  final now = DateTime.utc(2026, 8, 5, 12, 0);

  final sessionRoom = File(
    'lib/features/session/presentation/session_room_page.dart',
  ).readAsStringSync();

  Session session({List<String> ended = const []}) => Session(
    id: 's1',
    type: 'gym',
    title: 'Session',
    hostId: alice,
    participants: const [alice, bob],
    participantTypes: const {alice: 'gym', bob: 'gym'},
    status: SessionStatus.active,
    phase: SessionPhase.live,
    activeUserId: bob,
    createdAt: now,
    startedAt: now,
    endedParticipants: ended,
  );

  UserPresence live(String id) =>
      UserPresence(userId: id, status: PresenceStatus.online, lastChanged: now);

  UserPresence gone(String id) => UserPresence(
    userId: id,
    status: PresenceStatus.online,
    lastChanged: now.subtract(const Duration(minutes: 10)),
  );

  group('the member who stayed keeps training', () {
    test('is solo the moment their partner is unreachable', () {
      expect(
        isEffectivelySolo(
          userId: alice,
          session: session(),
          presence: {alice: live(alice), bob: gone(bob)},
          now: now,
        ),
        isTrue,
      );
    });

    test('can log an unbroken run of sets while the partner is away', () {
      // Ten handovers in a row must all come back to Alice. A single one going
      // to Bob would park her on a waiting screen.
      var current = alice;
      for (var i = 0; i < 10; i++) {
        current = nextTurnHolder(
              currentUserId: current,
              session: session(),
              presence: {alice: live(alice), bob: gone(bob)},
              now: now,
            ) ??
            'nobody';
        expect(current, alice);
      }
    });

    test('the turn never lands on the absent partner', () {
      expect(
        canHoldTurn(
          userId: bob,
          session: session(),
          presence: {alice: live(alice), bob: gone(bob)},
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('shared behaviour returns on its own', () {
    test('the partner reappearing makes it shared again', () {
      expect(
        isEffectivelySolo(
          userId: alice,
          session: session(),
          presence: {alice: live(alice), bob: live(bob)},
          now: now,
        ),
        isFalse,
      );
    });

    test('the turn goes back to the partner once they are present', () {
      expect(
        nextTurnHolder(
          currentUserId: alice,
          session: session(),
          presence: {alice: live(alice), bob: live(bob)},
          now: now,
        ),
        bob,
      );
    });
  });

  group('the session room actually uses the rule', () {
    test('the turn-based dispatch consults the solo evaluation', () {
      // Without this the member is shown WaitingTurnScreen whenever
      // activeUserId is not theirs, regardless of whether anyone is there.
      expect(sessionRoom.contains('_evaluateSolo('), isTrue);
      expect(
        sessionRoom.contains(
          'session.activeUserId == currentUserId || trainingAlone',
        ),
        isTrue,
      );
    });

    test('the shared↔solo transition is damped', () {
      expect(sessionRoom.contains('SoloModeDamper'), isTrue);
    });

    test('derivedMode is not mutated — the override is presentation only', () {
      // Changing the stored mode would stop the session reverting to shared on
      // its own when the partner returns. `derivedMode ==` comparisons are
      // fine; an assignment is not.
      expect(
        RegExp(r'derivedMode\s*=(?!=)').hasMatch(sessionRoom),
        isFalse,
      );
    });
  });

  group('a departed partner is not merely away', () {
    test('standing distinguishes the two', () {
      final s = session(ended: [bob]);
      expect(
        standingOf(
          userId: bob,
          session: s,
          presence: {bob: gone(bob)},
          now: now,
        ),
        ParticipantStanding.left,
      );
      expect(
        standingOf(
          userId: bob,
          session: session(),
          presence: {bob: gone(bob)},
          now: now,
        ),
        ParticipantStanding.away,
      );
    });

    test('the room feeds standing into the parallel views', () {
      expect(sessionRoom.contains('_partnerStanding('), isTrue);
      expect(sessionRoom.contains('standing: _partnerStanding('), isTrue);
    });
  });
}
