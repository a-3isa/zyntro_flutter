import '../../../../core/models/models.dart';
import '../domain/gym_session_plan.dart';
import '../domain/turn_plan_progress.dart';
import 'live_participant_progress.dart';

/// Resolved partner fields for the waiting-turn screen (Z-ARCH-002).
class WaitingTurnPartnerView {
  const WaitingTurnPartnerView({
    required this.partnerId,
    required this.currentExercise,
    required this.setNumber,
    required this.setElapsed,
  });

  final String? partnerId;
  final String currentExercise;
  final int setNumber;
  final Duration setElapsed;
}

/// Derives waiting-turn partner exercise/set/elapsed from session + plans.
WaitingTurnPartnerView resolveWaitingTurnPartner({
  required Session session,
  required Map<String, GymSessionPlan> plans,
  required Map<String, Map<String, int>> counts,
  required Map<String, LiveParticipantProgress> participantProgress,
  DateTime? now,
}) {
  final partnerId = session.activeUserId;
  final partnerProgress =
      partnerId != null ? participantProgress[partnerId] : null;
  final partnerPlan = partnerId != null ? plans[partnerId] : null;
  final partnerState = partnerPlan != null
      ? TurnPlanProgress.participantState(
          partnerPlan,
          counts[partnerId] ?? const {},
        )
      : null;
  final partnerCurrentExercise =
      partnerState?.currentExercise?.name ??
      partnerProgress?.currentExercise ??
      '';
  final partnerSetNumber =
      partnerState?.currentSetNumber ?? (partnerProgress?.totalSets ?? 0) + 1;

  final Duration partnerSetElapsed;
  final activeSetStart = session.activeSetStartedAt;
  if (activeSetStart != null) {
    final d = (now ?? DateTime.now()).difference(activeSetStart);
    partnerSetElapsed = d.isNegative ? Duration.zero : d;
  } else {
    partnerSetElapsed = Duration(
      seconds: partnerProgress?.lastSetSeconds ?? 0,
    );
  }

  return WaitingTurnPartnerView(
    partnerId: partnerId,
    currentExercise: partnerCurrentExercise,
    setNumber: partnerSetNumber,
    setElapsed: partnerSetElapsed,
  );
}
