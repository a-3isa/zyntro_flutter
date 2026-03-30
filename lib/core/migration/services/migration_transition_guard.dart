import '../models/migration_lifecycle.dart';

class TransitionPrerequisites {
  final bool hasRegressionEvidence;
  final bool hasSecurityEvidence;
  final bool telemetryBaselineActive;
  final bool rollbackReadinessConfirmed;
  final bool hasPostCutoverEvidence;
  final int unresolvedCriticalDefects;

  const TransitionPrerequisites({
    this.hasRegressionEvidence = false,
    this.hasSecurityEvidence = false,
    this.telemetryBaselineActive = false,
    this.rollbackReadinessConfirmed = false,
    this.hasPostCutoverEvidence = false,
    this.unresolvedCriticalDefects = 0,
  });
}

class TransitionGuardResult {
  final bool allowed;
  final String? reason;

  const TransitionGuardResult._({required this.allowed, this.reason});

  const TransitionGuardResult.allowed() : this._(allowed: true);

  const TransitionGuardResult.denied(String reason)
    : this._(allowed: false, reason: reason);
}

class MigrationTransitionGuard {
  const MigrationTransitionGuard();

  static const List<MigrationState> _orderedStates = [
    MigrationState.notStarted,
    MigrationState.inProgress,
    MigrationState.validationComplete,
    MigrationState.cutoverComplete,
    MigrationState.legacyRemoved,
  ];

  bool isForwardTransition(MigrationState from, MigrationState to) {
    final fromIndex = _orderedStates.indexOf(from);
    final toIndex = _orderedStates.indexOf(to);
    return toIndex > fromIndex;
  }

  TransitionGuardResult evaluate({
    required MigrationState from,
    required MigrationState to,
    TransitionPrerequisites prerequisites = const TransitionPrerequisites(),
  }) {
    final fromIndex = _orderedStates.indexOf(from);
    final toIndex = _orderedStates.indexOf(to);

    if (toIndex == fromIndex) {
      return const TransitionGuardResult.denied(
        'State transition must move forward.',
      );
    }

    if (!isForwardTransition(from, to)) {
      return const TransitionGuardResult.denied(
        'State transition order is invalid.',
      );
    }

    if (toIndex - fromIndex != 1) {
      return const TransitionGuardResult.denied(
        'State transition cannot skip required intermediate states.',
      );
    }

    switch (to) {
      case MigrationState.validationComplete:
        if (!prerequisites.hasRegressionEvidence ||
            !prerequisites.hasSecurityEvidence) {
          return const TransitionGuardResult.denied(
            'Validation completion requires passing regression and security evidence.',
          );
        }
        break;
      case MigrationState.cutoverComplete:
        if (!prerequisites.telemetryBaselineActive ||
            !prerequisites.rollbackReadinessConfirmed) {
          return const TransitionGuardResult.denied(
            'Cutover completion requires telemetry baseline and rollback readiness.',
          );
        }
        break;
      case MigrationState.legacyRemoved:
        if (prerequisites.unresolvedCriticalDefects > 0 ||
            !prerequisites.hasPostCutoverEvidence) {
          return const TransitionGuardResult.denied(
            'Legacy removal requires post-cutover evidence and no critical defects.',
          );
        }
        break;
      case MigrationState.notStarted:
      case MigrationState.inProgress:
        break;
    }

    return const TransitionGuardResult.allowed();
  }
}
