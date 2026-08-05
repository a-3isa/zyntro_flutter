import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/features/session/domain/resume_decision.dart';

/// The whole feature funnels through this one function, so every branch and
/// every boundary is asserted here. It is pure by design — no Firestore, no
/// widget tree, `now` injected — precisely so this table can exist.
void main() {
  final now = DateTime.utc(2026, 8, 5, 12, 0);

  ResumeCandidate candidate({
    SessionPhase phase = SessionPhase.live,
    SessionStatus status = SessionStatus.active,
    Duration? sinceActivity = Duration.zero,
    Duration? untilExpiry = const Duration(hours: 2),
    bool memberHasTerminated = false,
    bool otherParticipantPresent = false,
  }) {
    return ResumeCandidate(
      sessionId: 's1',
      workoutType: 'gym',
      phase: phase,
      status: status,
      lastActivityAt:
          sinceActivity == null ? null : now.subtract(sinceActivity),
      expiresAt: untilExpiry == null ? null : now.add(untilExpiry),
      memberHasTerminated: memberHasTerminated,
      otherParticipantPresent: otherParticipantPresent,
    );
  }

  ResumeDecision decide({
    ResumeCandidate? on,
    bool hasExplicitLaunchDestination = false,
    bool resumeEnabled = true,
    bool expiryAlreadyNotified = false,
  }) {
    return resolveResumeDecision(
      candidate: on,
      now: now,
      hasExplicitLaunchDestination: hasExplicitLaunchDestination,
      resumeEnabled: resumeEnabled,
      expiryAlreadyNotified: expiryAlreadyNotified,
    );
  }

  group('nothing to resume', () {
    test('no candidate session', () {
      expect(decide(on: null), isA<ResumeNone>());
    });
  });

  group('rule 1 — an explicit launch destination wins', () {
    test('a notification tap beats a warm session', () {
      expect(
        decide(on: candidate(), hasExplicitLaunchDestination: true),
        isA<ResumeNone>(),
        reason: 'tapping a notification must never be hijacked by a redirect',
      );
    });

    test('it even beats the kill switch being on', () {
      // Ordering matters: turning the feature off must not also break deep
      // links, so rule 1 sits above rule 2 rather than beside it.
      expect(
        decide(
          on: candidate(),
          hasExplicitLaunchDestination: true,
          resumeEnabled: false,
        ),
        isA<ResumeNone>(),
      );
    });
  });

  group('rule 2 — the kill switch', () {
    test('suppresses a warm redirect', () {
      expect(
        decide(on: candidate(), resumeEnabled: false),
        isA<ResumeNone>(),
      );
    });

    test('suppresses a quiet prompt', () {
      expect(
        decide(
          on: candidate(sinceActivity: const Duration(hours: 1)),
          resumeEnabled: false,
        ),
        isA<ResumeNone>(),
      );
    });

    test('suppresses an expiry notice', () {
      expect(
        decide(
          on: candidate(untilExpiry: const Duration(seconds: -1)),
          resumeEnabled: false,
        ),
        isA<ResumeNone>(),
      );
    });
  });

  group('rule 3 — a member who terminated', () {
    test('is never returned to that session', () {
      expect(
        decide(on: candidate(memberHasTerminated: true)),
        isA<ResumeNone>(),
      );
    });

    test('is not told it expired either', () {
      // Above the expiry branch on purpose — telling someone their session
      // "expired" when they deliberately ended it would be a lie.
      expect(
        decide(
          on: candidate(
            memberHasTerminated: true,
            untilExpiry: const Duration(seconds: -1),
          ),
        ),
        isA<ResumeNone>(),
      );
    });
  });

  group('rule 4 — live stage only', () {
    test('a session still in setup yields nothing', () {
      expect(
        decide(on: candidate(phase: SessionPhase.setup)),
        isA<ResumeNone>(),
      );
    });

    test('a completed session yields nothing', () {
      // There is no recap phase to test for: SessionPhase holds setup and live
      // only, and a wrapped-up session is simply completed.
      expect(
        decide(on: candidate(status: SessionStatus.completed)),
        isA<ResumeNone>(),
      );
    });

    test('a cancelled session yields nothing', () {
      expect(
        decide(on: candidate(status: SessionStatus.cancelled)),
        isA<ResumeNone>(),
      );
    });

    test('a paused session yields nothing', () {
      expect(
        decide(on: candidate(status: SessionStatus.paused)),
        isA<ResumeNone>(),
      );
    });
  });

  group('rule 5 — expiry', () {
    test('an expired session produces a notice, not a redirect', () {
      final decision =
          decide(on: candidate(untilExpiry: const Duration(seconds: -1)));
      expect(decision, isA<ResumeExpiredNotice>());
      expect((decision as ResumeExpiredNotice).sessionId, 's1');
    });

    test('expiry is inclusive at the boundary', () {
      expect(
        decide(on: candidate(untilExpiry: Duration.zero)),
        isA<ResumeExpiredNotice>(),
      );
      expect(
        decide(on: candidate(untilExpiry: const Duration(seconds: 1))),
        isA<ResumeRedirect>(),
      );
    });

    test('a session with no expiry counts as expired', () {
      // Written before this feature: the sweep cannot see it, so it must never
      // be resumed either.
      expect(
        decide(on: candidate(untilExpiry: null)),
        isA<ResumeExpiredNotice>(),
      );
    });

    test('the notice is not repeated once the member has been told', () {
      expect(
        decide(
          on: candidate(untilExpiry: const Duration(seconds: -1)),
          expiryAlreadyNotified: true,
        ),
        isA<ResumeNone>(),
      );
    });
  });

  group('rule 6 — warm sessions redirect', () {
    test('recent work goes straight in', () {
      final decision = decide(on: candidate(sinceActivity: Duration.zero));
      expect(decision, isA<ResumeRedirect>());
      expect((decision as ResumeRedirect).sessionId, 's1');
      expect(decision.workoutType, 'gym');
    });

    test('a partner in the room makes an otherwise quiet session warm', () {
      expect(
        decide(
          on: candidate(
            sinceActivity: const Duration(hours: 1),
            otherParticipantPresent: true,
          ),
        ),
        isA<ResumeRedirect>(),
        reason: 'someone else is actively training — the session is alive',
      );
    });
  });

  group('rule 7 — quiet sessions ask first', () {
    test('an hour of silence with an empty room prompts', () {
      final decision =
          decide(on: candidate(sinceActivity: const Duration(hours: 1)));
      expect(decision, isA<ResumePrompt>());
      expect((decision as ResumePrompt).sessionId, 's1');
    });

    test('the warm boundary is exclusive', () {
      expect(
        decide(
          on: candidate(
            sinceActivity: kWarmSessionWindow - const Duration(seconds: 1),
          ),
        ),
        isA<ResumeRedirect>(),
      );
      expect(
        decide(on: candidate(sinceActivity: kWarmSessionWindow)),
        isA<ResumePrompt>(),
      );
    });

    test('unknown activity is treated as quiet, never as warm', () {
      // "We don't know when this was last worked in" must not become a silent
      // redirect.
      expect(
        decide(on: candidate(sinceActivity: null)),
        isA<ResumePrompt>(),
      );
    });

    test('a session going warm does not retroactively change the decision', () {
      // The decision is latched at cold start, so a partner starting to log
      // sets while the prompt is on screen leaves the prompt standing.
      final quiet = candidate(sinceActivity: const Duration(hours: 1));
      expect(decide(on: quiet), isA<ResumePrompt>());
      expect(decide(on: quiet), isA<ResumePrompt>());
    });
  });

  group('totality', () {
    test('every combination yields a decision and never throws', () {
      for (final phase in SessionPhase.values) {
        for (final status in SessionStatus.values) {
          for (final terminated in [true, false]) {
            for (final present in [true, false]) {
              for (final expiry in [
                null,
                const Duration(hours: 1),
                const Duration(seconds: -1),
              ]) {
                for (final activity in [
                  null,
                  Duration.zero,
                  const Duration(hours: 1),
                ]) {
                  expect(
                    decide(
                      on: candidate(
                        phase: phase,
                        status: status,
                        memberHasTerminated: terminated,
                        otherParticipantPresent: present,
                        untilExpiry: expiry,
                        sinceActivity: activity,
                      ),
                    ),
                    isA<ResumeDecision>(),
                  );
                }
              }
            }
          }
        }
      }
    });
  });
}
