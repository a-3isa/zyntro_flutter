import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/features/session/domain/resume_decision.dart';

void main() {
  test('resolveResumeDecision stays under SC-002 2s budget (Z-REPO-005)', () {
    final candidate = ResumeCandidate(
      sessionId: 's1',
      workoutType: 'gym',
      phase: SessionPhase.live,
      status: SessionStatus.active,
      lastActivityAt: DateTime(2026, 9, 17, 12),
      expiresAt: DateTime(2026, 9, 17, 14),
      memberHasTerminated: false,
      otherParticipantPresent: true,
    );
    final now = DateTime(2026, 9, 17, 12, 5);

    final sw = Stopwatch()..start();
    for (var i = 0; i < 5000; i++) {
      resolveResumeDecision(
        candidate: candidate,
        now: now,
        hasExplicitLaunchDestination: false,
        resumeEnabled: true,
        expiryAlreadyNotified: false,
      );
    }
    sw.stop();

    // Pure decision must be negligible vs the 2s wall-clock product budget.
    expect(sw.elapsedMilliseconds, lessThan(500));
  });
}
