import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/session/domain/turn_eligibility.dart';
import 'package:zyntro_flutter/services/presence_service.dart';

/// A turn-based session must never stall on someone whose app is closed. The
/// member who stayed keeps training; the session quietly becomes solo for them
/// and reverts the moment their partner returns.
void main() {
  const alice = 'alice';
  const bob = 'bob';
  final now = DateTime.utc(2026, 8, 5, 12, 0);

  Session sessionWith({
    List<String> participants = const [alice, bob],
    List<String> endedParticipants = const [],
  }) {
    return Session(
      id: 's1',
      type: 'gym',
      title: 'Session',
      hostId: alice,
      participants: participants,
      status: SessionStatus.active,
      phase: SessionPhase.live,
      createdAt: now,
      startedAt: now,
      endedParticipants: endedParticipants,
    );
  }

  UserPresence present(String userId) =>
      UserPresence(userId: userId, status: PresenceStatus.online, lastChanged: now);

  UserPresence stale(String userId) => UserPresence(
    userId: userId,
    status: PresenceStatus.online,
    lastChanged: now.subtract(const Duration(minutes: 10)),
  );

  group('canHoldTurn', () {
    test('a present participant can', () {
      expect(
        canHoldTurn(
          userId: alice,
          session: sessionWith(),
          presence: {alice: present(alice)},
          now: now,
        ),
        isTrue,
      );
    });

    test('someone whose app is closed cannot, while they are away', () {
      expect(
        canHoldTurn(
          userId: bob,
          session: sessionWith(),
          presence: {bob: stale(bob)},
          now: now,
        ),
        isFalse,
      );
    });

    test('someone who terminated cannot, even if their record looks fresh', () {
      // Left beats away: presence is irrelevant once they have gone for good.
      expect(
        canHoldTurn(
          userId: bob,
          session: sessionWith(endedParticipants: [bob]),
          presence: {bob: present(bob)},
          now: now,
        ),
        isFalse,
      );
    });

    test('a non-participant never can', () {
      expect(
        canHoldTurn(
          userId: 'mallory',
          session: sessionWith(),
          presence: {'mallory': present('mallory')},
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('nextTurnHolder', () {
    test('passes to the partner when they are present', () {
      expect(
        nextTurnHolder(
          currentUserId: alice,
          session: sessionWith(),
          presence: {alice: present(alice), bob: present(bob)},
          now: now,
        ),
        bob,
      );
    });

    test('returns the turn to the member still training when the partner is away',
        () {
      // The whole point: Alice finishes her set and goes straight into the next
      // one instead of waiting on a Bob who is not there.
      expect(
        nextTurnHolder(
          currentUserId: alice,
          session: sessionWith(),
          presence: {alice: present(alice), bob: stale(bob)},
          now: now,
        ),
        alice,
      );
    });

    test('skips a partner who terminated', () {
      expect(
        nextTurnHolder(
          currentUserId: alice,
          session: sessionWith(endedParticipants: [bob]),
          presence: {alice: present(alice), bob: present(bob)},
          now: now,
        ),
        alice,
      );
    });

    test('returns null when nobody can act', () {
      // Both apps are closed. Leaving activeUserId untouched is correct here —
      // this session is heading for expiry anyway.
      expect(
        nextTurnHolder(
          currentUserId: alice,
          session: sessionWith(),
          presence: {alice: stale(alice), bob: stale(bob)},
          now: now,
        ),
        isNull,
      );
    });

    test('never leaves the turn with nobody holding it', () {
      // Whatever the presence combination, the answer is either a specific
      // eligible member or an explicit null — never a silent stall.
      for (final aliceLive in [true, false]) {
        for (final bobLive in [true, false]) {
          final holder = nextTurnHolder(
            currentUserId: alice,
            session: sessionWith(),
            presence: {
              alice: aliceLive ? present(alice) : stale(alice),
              bob: bobLive ? present(bob) : stale(bob),
            },
            now: now,
          );
          if (!aliceLive && !bobLive) {
            expect(holder, isNull);
          } else {
            expect(holder, isNotNull);
          }
        }
      }
    });
  });

  group('isEffectivelySolo', () {
    test('false while the partner is in the room', () {
      expect(
        isEffectivelySolo(
          userId: alice,
          session: sessionWith(),
          presence: {alice: present(alice), bob: present(bob)},
          now: now,
        ),
        isFalse,
      );
    });

    test('true once the partner closes their app', () {
      expect(
        isEffectivelySolo(
          userId: alice,
          session: sessionWith(),
          presence: {alice: present(alice), bob: stale(bob)},
          now: now,
        ),
        isTrue,
      );
    });

    test('reverts to shared the moment the partner returns', () {
      final presence = {alice: present(alice), bob: stale(bob)};
      expect(
        isEffectivelySolo(
          userId: alice,
          session: sessionWith(),
          presence: presence,
          now: now,
        ),
        isTrue,
      );

      presence[bob] = present(bob);
      expect(
        isEffectivelySolo(
          userId: alice,
          session: sessionWith(),
          presence: presence,
          now: now,
        ),
        isFalse,
      );
    });

    test('a genuinely solo session is solo', () {
      expect(
        isEffectivelySolo(
          userId: alice,
          session: sessionWith(participants: [alice]),
          presence: {alice: present(alice)},
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('SoloModeDamper — the transition must not flicker', () {
    test('does not drop to solo the instant a partner goes quiet', () {
      final damper = SoloModeDamper();
      expect(damper.update(rawSolo: true, now: now), isFalse);
    });

    test('drops to solo once the grace period has elapsed', () {
      final damper = SoloModeDamper();
      damper.update(rawSolo: true, now: now);

      expect(
        damper.update(
          rawSolo: true,
          now: now.add(SoloModeDamper.graceBeforeSolo),
        ),
        isTrue,
      );
    });

    test('a partner reappearing mid-grace cancels the drop entirely', () {
      final damper = SoloModeDamper();
      damper.update(rawSolo: true, now: now);
      damper.update(
        rawSolo: false,
        now: now.add(const Duration(seconds: 10)),
      );

      // The clock restarts — the earlier blip must not count towards it.
      expect(
        damper.update(
          rawSolo: true,
          now: now.add(const Duration(seconds: 11)),
        ),
        isFalse,
      );
    });

    test('coming back to shared is immediate, with no grace period', () {
      final damper = SoloModeDamper();
      damper.update(rawSolo: true, now: now);
      damper.update(
        rawSolo: true,
        now: now.add(SoloModeDamper.graceBeforeSolo),
      );
      expect(damper.isSolo, isTrue);

      expect(
        damper.update(
          rawSolo: false,
          now: now.add(SoloModeDamper.graceBeforeSolo),
        ),
        isFalse,
        reason: 'being slow to notice a partner returned is the costly error',
      );
    });

    test('repeated flapping never toggles the view', () {
      // A weak connection lapsing and recovering every few seconds must leave
      // the member in shared mode throughout, not strobing between the two.
      final damper = SoloModeDamper();
      var t = now;
      for (var i = 0; i < 20; i++) {
        t = t.add(const Duration(seconds: 5));
        expect(damper.update(rawSolo: i.isEven, now: t), isFalse);
      }
    });

    test('a sustained absence still wins in the end', () {
      final damper = SoloModeDamper();
      var t = now;
      for (var i = 0; i < 10; i++) {
        t = t.add(const Duration(seconds: 5));
        damper.update(rawSolo: true, now: t);
      }
      expect(damper.isSolo, isTrue);
    });
  });

  group('standingOf — away and left must not look the same', () {
    test('present reads as active', () {
      expect(
        standingOf(
          userId: bob,
          session: sessionWith(),
          presence: {bob: present(bob)},
          now: now,
        ),
        ParticipantStanding.active,
      );
    });

    test('app closed reads as away, not left', () {
      expect(
        standingOf(
          userId: bob,
          session: sessionWith(),
          presence: {bob: stale(bob)},
          now: now,
        ),
        ParticipantStanding.away,
      );
    });

    test('terminated reads as left', () {
      expect(
        standingOf(
          userId: bob,
          session: sessionWith(endedParticipants: [bob]),
          presence: {bob: stale(bob)},
          now: now,
        ),
        ParticipantStanding.left,
      );
    });

    test('left wins over away when both would apply', () {
      // Someone who terminated and then closed their app is gone, not absent.
      expect(
        standingOf(
          userId: bob,
          session: sessionWith(endedParticipants: [bob]),
          presence: const {},
          now: now,
        ),
        ParticipantStanding.left,
      );
    });
  });
}
