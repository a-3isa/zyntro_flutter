import '../models/migration_lifecycle.dart';
import '../models/migration_slice.dart';
import 'migration_transition_guard.dart';

class MigrationStateMachine {
  final MigrationTransitionGuard _transitionGuard;

  const MigrationStateMachine(this._transitionGuard);

  TransitionGuardResult validateTransition({
    required MigrationState from,
    required MigrationState to,
    TransitionPrerequisites prerequisites = const TransitionPrerequisites(),
  }) {
    return _transitionGuard.evaluate(
      from: from,
      to: to,
      prerequisites: prerequisites,
    );
  }

  MigrationSlice transition({
    required MigrationSlice slice,
    required MigrationState toState,
    required String reason,
    TransitionPrerequisites prerequisites = const TransitionPrerequisites(),
    DateTime? now,
  }) {
    final result = validateTransition(
      from: slice.state,
      to: toState,
      prerequisites: prerequisites,
    );

    if (!result.allowed) {
      throw StateError(result.reason ?? 'Migration transition rejected.');
    }

    return slice.copyWith(state: toState, updatedAt: now ?? DateTime.now());
  }

  MigrationTransition createTransitionRecord({
    required MigrationState from,
    required MigrationState to,
    required String reason,
    DateTime? occurredAt,
  }) {
    return MigrationTransition(
      fromState: from,
      toState: to,
      reason: reason,
      occurredAt: occurredAt ?? DateTime.now(),
    );
  }
}
