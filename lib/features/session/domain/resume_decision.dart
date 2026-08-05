import '../../../core/constants/constants.dart';
import '../../../core/models/models.dart';

/// What to do at cold start about a session the member may still be in.
///
/// Deliberately a pure decision over already-fetched state: no I/O, no clock
/// reads, `now` injected. That is what makes every branch of the table below
/// testable without Firestore or a widget tree — which the constitution
/// requires as cutover evidence.
sealed class ResumeDecision {
  const ResumeDecision();
}

/// Show the default landing screen. Nothing to resume.
class ResumeNone extends ResumeDecision {
  const ResumeNone();
}

/// The session is warm — go straight in, no confirmation.
class ResumeRedirect extends ResumeDecision {
  final String sessionId;
  final String workoutType;
  const ResumeRedirect(this.sessionId, this.workoutType);
}

/// The session is quiet — ask whether to continue or discard before going in.
class ResumePrompt extends ResumeDecision {
  final String sessionId;
  final String workoutType;
  const ResumePrompt(this.sessionId, this.workoutType);
}

/// The session ended while the member was away. Tell them what happened.
class ResumeExpiredNotice extends ResumeDecision {
  final String sessionId;
  const ResumeExpiredNotice(this.sessionId);
}

/// Everything the decision needs about the candidate session, resolved before
/// the router runs.
class ResumeCandidate {
  final String sessionId;
  final String workoutType;
  final SessionPhase phase;
  final SessionStatus status;
  final DateTime? lastActivityAt;
  final DateTime? expiresAt;
  final bool memberHasTerminated;

  /// Whether another participant is in the room *right now* — already filtered
  /// for staleness, because a force-killed app leaves `online` behind forever.
  final bool otherParticipantPresent;

  const ResumeCandidate({
    required this.sessionId,
    required this.workoutType,
    required this.phase,
    required this.status,
    required this.lastActivityAt,
    required this.expiresAt,
    required this.memberHasTerminated,
    required this.otherParticipantPresent,
  });

  factory ResumeCandidate.fromSession(
    Session session,
    String userId, {
    required bool otherParticipantPresent,
  }) {
    return ResumeCandidate(
      sessionId: session.id,
      workoutType: session.participantTypes[userId] ?? session.type,
      phase: session.phase,
      status: session.status,
      lastActivityAt: session.lastActivityAt,
      expiresAt: session.expiresAt,
      memberHasTerminated: session.hasTerminated(userId),
      otherParticipantPresent: otherParticipantPresent,
    );
  }
}

/// How recently a session must have been worked in to count as still going.
///
/// Long enough to cover a slow rest between sets or a stretch of scrolling;
/// short enough that anything longer reads as an interruption the member may
/// not want resumed without being asked.
const kWarmSessionWindow = Duration(minutes: 15);

/// Decides what a cold start should do about [candidate].
///
/// Rules are evaluated in order and the first match wins. The order carries
/// meaning — see the notes on individual branches.
ResumeDecision resolveResumeDecision({
  required ResumeCandidate? candidate,
  required DateTime now,
  required bool hasExplicitLaunchDestination,
  required bool resumeEnabled,
  required bool expiryAlreadyNotified,
}) {
  // 1. A notification tap or deep link is the member telling us where they want
  //    to be. It outranks everything, including the kill switch — turning the
  //    feature off must not also break deep links.
  if (hasExplicitLaunchDestination) return const ResumeNone();

  // 2. Kill switch. Below the deep-link rule, above everything else.
  if (!resumeEnabled) return const ResumeNone();

  if (candidate == null) return const ResumeNone();

  // 3. Above the expiry branch on purpose: a member who walked out should not
  //    be told "your session expired" about a session they deliberately ended.
  if (candidate.memberHasTerminated) return const ResumeNone();

  // 4. Live stage only. A session in setup is not a workout in progress, and a
  //    wrapped-up one is simply completed — there is no third stage to test.
  if (candidate.phase != SessionPhase.live ||
      candidate.status != SessionStatus.active) {
    return const ResumeNone();
  }

  // 5. A session with no expiry predates this feature: the sweep cannot see it,
  //    so it must never be resumed either. The sweep runs every 15 minutes, so
  //    expiry is judged here rather than trusting `status` to have caught up.
  if (candidate.expiresAt == null || !now.isBefore(candidate.expiresAt!)) {
    return expiryAlreadyNotified
        ? const ResumeNone()
        : ResumeExpiredNotice(candidate.sessionId);
  }

  // 6. Warm: recent work, or a partner still in the room. Go straight in.
  final lastActivityAt = candidate.lastActivityAt;
  final workedRecently = lastActivityAt != null &&
      now.difference(lastActivityAt) < kWarmSessionWindow;
  if (workedRecently || candidate.otherParticipantPresent) {
    return ResumeRedirect(candidate.sessionId, candidate.workoutType);
  }

  // 7. Quiet but still inside the window: ask first. Unknown activity lands
  //    here too — never treat "we don't know" as warm.
  return ResumePrompt(candidate.sessionId, candidate.workoutType);
}
