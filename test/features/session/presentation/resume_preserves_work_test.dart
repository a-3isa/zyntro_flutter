import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/features/session/domain/resume_decision.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';

/// A member's logged sets survive an app restart for one reason: the app no
/// longer destroys the session on the way out. There is no restore step to
/// test — there is an absence to protect.
///
/// So these are source contracts. A behavioural test cannot catch someone
/// reinstating `endSession()` in the lifecycle handler, because the session
/// would be gone before any assertion ran; the work would simply be missing,
/// and every test that never looked would still pass.
void main() {
  final sessionRoom = File(
    'lib/features/session/presentation/session_room_page.dart',
  ).readAsStringSync();

  group('the app must not destroy a session on the way out (FR-005)', () {
    test('no summary-less endSession call remains', () {
      // Both removed terminators — the lifecycle handler and the inactivity
      // timer — ended the session with a null summary, because no member had
      // asked to finish. Finishing on purpose passes a real summary, so this
      // signature is precisely the involuntary kind and must not come back.
      expect(
        sessionRoom.contains('endSession(widget.sessionId, uid, null)'),
        isFalse,
        reason: 'closing the app must not complete the member\'s workout',
      );
    });

    test('finishing deliberately still ends the session', () {
      // The removal must be surgical — the member pressing Finish still works.
      expect(sessionRoom.contains('endSession(widget.sessionId, uid, summary)'),
          isTrue);
    });

    test('detached and hidden still mark the member away', () {
      // The removal is surgical: presence still has to be released, or the
      // partner keeps seeing a ghost in the room.
      expect(sessionRoom.contains('AppLifecycleState.detached'), isTrue);
      expect(sessionRoom.contains('setAway'), isTrue);
    });

    test('the client-side inactivity terminator is gone', () {
      // A 10-minute client timer contradicted the agreed 3-hour window, and
      // only ran while the screen was mounted — punishing the member who
      // stayed in the app while doing nothing about the one who force-closed.
      expect(sessionRoom.contains('_terminateSessionInactive'), isFalse);
      expect(sessionRoom.contains('_inactivityLimit'), isFalse);
    });

    test('expiry is left to the scheduled function', () {
      final functions = File('functions/index.js').readAsStringSync();
      expect(functions.contains('exports.expireStaleSessions'), isTrue);
      expect(functions.contains('"every 15 minutes"'), isTrue);
    });
  });

  group('resuming reads, it never writes (FR-005)', () {
    test('the decision cannot mutate a session — it has nothing to write with',
        () {
      // resolveResumeDecision is pure: it takes a snapshot of state and returns
      // an enum. There is no Firestore handle in scope, so no code path through
      // it can drop, re-count, or duplicate a logged set.
      final source = File(
        'lib/features/session/domain/resume_decision.dart',
      ).readAsStringSync();

      expect(source.contains('cloud_firestore'), isFalse);
      expect(source.contains('FirebaseFirestore'), isFalse);
      expect(source.contains('.update('), isFalse);
      expect(source.contains('.set('), isFalse);
      expect(source.contains('.delete('), isFalse);
    });
  });

  group('start-up stays bounded (SC-002)', () {
    test('the resumable-session query is limited', () {
      // An unbounded query over a member's session history would put start-up
      // latency at the mercy of how long they have used the app.
      final service =
          File('lib/services/session_service.dart').readAsStringSync();
      final query = service.substring(
        service.indexOf('Future<ResumeCandidate?> findResumableSession'),
        service.indexOf('Future<ResumeCandidate?> findResumableSession') + 1200,
      );

      expect(query.contains('.limit('), isTrue);
      expect(query.contains('.orderBy('), isTrue);
    });

    test('the lookup degrades to no-session instead of throwing into start-up',
        () {
      final service =
          File('lib/services/session_service.dart').readAsStringSync();
      final query = service.substring(
        service.indexOf('Future<ResumeCandidate?> findResumableSession'),
        service.indexOf('Future<ResumeCandidate?> findResumableSession') + 1600,
      );

      expect(query.contains('catch'), isTrue);
      expect(query.contains('return null'), isTrue);
    });

    test('the decision itself costs nothing measurable', () {
      final candidate = ResumeCandidate(
        sessionId: 's1',
        workoutType: 'gym',
        phase: SessionPhase.live,
        status: SessionStatus.active,
        lastActivityAt: DateTime.utc(2026, 8, 5, 11, 59),
        expiresAt: DateTime.utc(2026, 8, 5, 14, 0),
        memberHasTerminated: false,
        otherParticipantPresent: false,
      );
      final now = DateTime.utc(2026, 8, 5, 12, 0);

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 10000; i++) {
        resolveResumeDecision(
          candidate: candidate,
          now: now,
          hasExplicitLaunchDestination: false,
          resumeEnabled: true,
          expiryAlreadyNotified: false,
        );
      }
      stopwatch.stop();

      // The 2-second budget is spent on the network round-trip and the first
      // frame, never here. If this ever became slow, something stateful had
      // been smuggled into a function that is supposed to be pure.
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
