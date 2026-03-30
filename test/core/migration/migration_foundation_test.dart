import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/migration/migration.dart';

void main() {
  group('MigrationTransitionGuard', () {
    const guard = MigrationTransitionGuard();

    test('allows first forward transition', () {
      final result = guard.evaluate(
        from: MigrationState.notStarted,
        to: MigrationState.inProgress,
      );

      expect(result.allowed, isTrue);
    });

    test('rejects skipped state transition', () {
      final result = guard.evaluate(
        from: MigrationState.notStarted,
        to: MigrationState.validationComplete,
      );

      expect(result.allowed, isFalse);
      expect(result.reason, contains('cannot skip'));
    });

    test('requires regression and security evidence for validation completion', () {
      final result = guard.evaluate(
        from: MigrationState.inProgress,
        to: MigrationState.validationComplete,
      );

      expect(result.allowed, isFalse);
      expect(result.reason, contains('regression and security'));
    });

    test('allows validation completion when evidence is present', () {
      final result = guard.evaluate(
        from: MigrationState.inProgress,
        to: MigrationState.validationComplete,
        prerequisites: const TransitionPrerequisites(
          hasRegressionEvidence: true,
          hasSecurityEvidence: true,
        ),
      );

      expect(result.allowed, isTrue);
    });
  });

  group('MigrationEvidencePolicy', () {
    const policy = MigrationEvidencePolicy();

    test('uses 95% as regression threshold', () {
      expect(policy.regressionGatePassed(95), isTrue);
      expect(policy.regressionGatePassed(94.9), isFalse);
    });

    test('disallows critical security defects at cutover', () {
      expect(policy.securityGatePassed(0), isTrue);
      expect(policy.securityGatePassed(1), isFalse);
    });

    test('requires telemetry baseline and rollback readiness', () {
      expect(
        policy.cutoverOperationalGatePassed(
          telemetryBaselineActive: true,
          rollbackReadinessConfirmed: true,
        ),
        isTrue,
      );

      expect(
        policy.cutoverOperationalGatePassed(
          telemetryBaselineActive: true,
          rollbackReadinessConfirmed: false,
        ),
        isFalse,
      );
    });
  });
}
