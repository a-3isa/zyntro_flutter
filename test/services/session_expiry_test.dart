import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/services/session_service.dart';

/// The app can no longer close a session on its own — terminating on app-close
/// destroyed the very session a member wanted to come back to, and `detached`
/// is not delivered reliably on a force-quit anyway. Expiry is therefore
/// server-side, driven entirely by the `expiresAt` these stamps maintain.
///
/// If the stamps are wrong, sessions either die under a member who is still
/// working out, or live forever with nobody in them.
void main() {
  final now = DateTime.utc(2026, 8, 5, 12, 0);

  Session sessionWith({
    DateTime? expiresAt,
    DateTime? lastActivityAt,
    SessionPhase phase = SessionPhase.live,
    SessionStatus status = SessionStatus.active,
    List<String> participants = const ['alice', 'bob'],
    List<String> endedParticipants = const [],
  }) {
    return Session(
      id: 's1',
      type: 'gym',
      title: 'Session',
      hostId: 'alice',
      participants: participants,
      status: status,
      phase: phase,
      createdAt: now.subtract(const Duration(hours: 1)),
      startedAt: now.subtract(const Duration(hours: 1)),
      lastActivityAt: lastActivityAt,
      expiresAt: expiresAt,
      endedParticipants: endedParticipants,
    );
  }

  group('the inactivity limit', () {
    test('is three hours', () {
      expect(Session.inactivityLimit, const Duration(hours: 3));
    });
  });

  group('Session.isExpiredAt', () {
    test('is not expired while expiry is still ahead', () {
      final s = sessionWith(expiresAt: now.add(const Duration(minutes: 1)));
      expect(s.isExpiredAt(now), isFalse);
    });

    test('is expired once expiry has passed', () {
      final s = sessionWith(expiresAt: now.subtract(const Duration(minutes: 1)));
      expect(s.isExpiredAt(now), isTrue);
    });

    test('is expired exactly at the boundary', () {
      expect(sessionWith(expiresAt: now).isExpiredAt(now), isTrue);
    });

    test('treats a session with no expiry as already expired', () {
      // Sessions written before this feature have no `expiresAt`, so the
      // scheduled sweep cannot see them. If they also read as resumable they
      // would redirect forever with nothing able to close them.
      expect(sessionWith(expiresAt: null).isExpiredAt(now), isTrue);
    });
  });

  group('Session.isResumableFor', () {
    final live = now.add(const Duration(hours: 2));

    test('a live, active session the member is in is resumable', () {
      expect(sessionWith(expiresAt: live).isResumableFor('alice', now), isTrue);
    });

    test('a session still in setup is not resumable', () {
      expect(
        sessionWith(expiresAt: live, phase: SessionPhase.setup)
            .isResumableFor('alice', now),
        isFalse,
      );
    });

    test('a completed session is not resumable', () {
      // There is no separate "wrap-up" stage to check for: a wrapped-up session
      // is simply completed, and SessionPhase only holds setup and live.
      expect(
        sessionWith(expiresAt: live, status: SessionStatus.completed)
            .isResumableFor('alice', now),
        isFalse,
      );
    });

    test('a cancelled session is not resumable', () {
      expect(
        sessionWith(expiresAt: live, status: SessionStatus.cancelled)
            .isResumableFor('alice', now),
        isFalse,
      );
    });

    test('an expired session is not resumable', () {
      expect(
        sessionWith(expiresAt: now.subtract(const Duration(seconds: 1)))
            .isResumableFor('alice', now),
        isFalse,
      );
    });

    test('a non-participant can never resume it', () {
      expect(
        sessionWith(expiresAt: live).isResumableFor('mallory', now),
        isFalse,
      );
    });

    test('a member who terminated is not returned to it', () {
      expect(
        sessionWith(expiresAt: live, endedParticipants: ['alice'])
            .isResumableFor('alice', now),
        isFalse,
      );
    });

    test('a partner terminating does NOT disqualify the one still training',
        () {
      // Terminating is per-member. Bob walked out; Alice is still mid-workout
      // and must still be brought back to it.
      final s = sessionWith(expiresAt: live, endedParticipants: ['bob']);
      expect(s.isResumableFor('alice', now), isTrue);
      expect(s.isResumableFor('bob', now), isFalse);
    });
  });

  group('SessionService.activityStamp', () {
    test('moves both the activity clock and the derived expiry', () {
      final stamp = SessionService.activityStamp();
      expect(stamp['lastActivityAt'], isA<FieldValue>());
      expect(stamp['expiresAt'], isA<Timestamp>());
    });

    test('pushes expiry three hours out', () {
      final before = DateTime.now().toUtc();
      final expiresAt = SessionService.activityStamp()['expiresAt'] as Timestamp;
      final after = DateTime.now().toUtc();

      expect(
        expiresAt.toDate().isAfter(before.add(const Duration(hours: 3, seconds: -5))),
        isTrue,
      );
      expect(
        expiresAt.toDate().isBefore(after.add(const Duration(hours: 3, seconds: 5))),
        isTrue,
      );
    });

    test('never writes occupancy — logging work is not the same as sitting there',
        () {
      expect(SessionService.activityStamp().containsKey('lastOccupiedAt'), isFalse);
    });
  });

  group('SessionService.occupancyStamp', () {
    test('pushes expiry out without touching the activity clock', () {
      final stamp = SessionService.occupancyStamp();
      expect(stamp['lastOccupiedAt'], isA<FieldValue>());
      expect(stamp['expiresAt'], isA<Timestamp>());
      // Viewing a session counts as presence, never as activity (FR-007a).
      // If it stamped activity, a session nobody is working in would read as
      // warm and redirect with no prompt.
      expect(stamp.containsKey('lastActivityAt'), isFalse);
    });
  });

  group('a solo member training on keeps the session alive', () {
    test('their logged work pushes expiry past the original three hours', () {
      // The partner closed their app; the remaining member is still logging
      // sets. Expiry must ride forward on that work rather than counting down
      // from when the session started.
      //
      // activityStamp() reads the wall clock, so this test does too — mixing a
      // fixed fake clock with the real one makes the assertion depend on the
      // time of day the suite happens to run.
      final realNow = DateTime.now().toUtc();
      final startedNearlyThreeHoursAgo =
          realNow.subtract(const Duration(hours: 2, minutes: 55));

      final stampedExpiry =
          SessionService.activityStamp()['expiresAt'] as Timestamp;

      expect(
        stampedExpiry.toDate().isAfter(
              startedNearlyThreeHoursAgo.add(Session.inactivityLimit),
            ),
        isTrue,
        reason: 'expiry must extend beyond 3h from session start',
      );
      expect(
        sessionWith(expiresAt: stampedExpiry.toDate())
            .isResumableFor('alice', realNow),
        isTrue,
      );
    });
  });
}
