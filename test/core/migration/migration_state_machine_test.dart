import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/migration/migration.dart';

void main() {
  late MigrationStateMachine stateMachine;
  late MigrationSlice slice;

  setUp(() {
    stateMachine = const MigrationStateMachine(MigrationTransitionGuard());
    slice = MigrationSlice.authDefault(now: DateTime.utc(2026, 3, 11));
  });

  test('transitions sequentially from NOT_STARTED to IN_PROGRESS', () {
    final updated = stateMachine.transition(
      slice: slice,
      toState: MigrationState.inProgress,
      reason: 'Start migration',
    );

    expect(updated.state, MigrationState.inProgress);
  });

  test('blocks IN_PROGRESS to VALIDATION_COMPLETE without evidence', () {
    final inProgress = stateMachine.transition(
      slice: slice,
      toState: MigrationState.inProgress,
      reason: 'Start migration',
    );

    expect(
      () => stateMachine.transition(
        slice: inProgress,
        toState: MigrationState.validationComplete,
        reason: 'Validation complete',
      ),
      throwsStateError,
    );
  });

  test('allows full forward lifecycle with prerequisites', () {
    final inProgress = stateMachine.transition(
      slice: slice,
      toState: MigrationState.inProgress,
      reason: 'Start migration',
    );

    final validationComplete = stateMachine.transition(
      slice: inProgress,
      toState: MigrationState.validationComplete,
      reason: 'Validation complete',
      prerequisites: const TransitionPrerequisites(
        hasRegressionEvidence: true,
        hasSecurityEvidence: true,
      ),
    );

    final cutoverComplete = stateMachine.transition(
      slice: validationComplete,
      toState: MigrationState.cutoverComplete,
      reason: 'Cutover complete',
      prerequisites: const TransitionPrerequisites(
        hasRegressionEvidence: true,
        hasSecurityEvidence: true,
        telemetryBaselineActive: true,
        rollbackReadinessConfirmed: true,
      ),
    );

    final legacyRemoved = stateMachine.transition(
      slice: cutoverComplete,
      toState: MigrationState.legacyRemoved,
      reason: 'Legacy removed',
      prerequisites: const TransitionPrerequisites(
        hasRegressionEvidence: true,
        hasSecurityEvidence: true,
        telemetryBaselineActive: true,
        rollbackReadinessConfirmed: true,
        hasPostCutoverEvidence: true,
        unresolvedCriticalDefects: 0,
      ),
    );

    expect(legacyRemoved.state, MigrationState.legacyRemoved);
  });
}
