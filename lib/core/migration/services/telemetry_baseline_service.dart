import '../models/domain_failure_category.dart';
import '../models/telemetry_baseline.dart';
import 'migration_evidence_policy.dart';

class RollbackTriggerEvaluation {
  final bool shouldTriggerRollback;
  final String reason;
  final String triggerFailureCode;

  const RollbackTriggerEvaluation({
    required this.shouldTriggerRollback,
    required this.reason,
    required this.triggerFailureCode,
  });
}

class TelemetryBaselineService {
  final MigrationEvidencePolicy _evidencePolicy;

  const TelemetryBaselineService(this._evidencePolicy);

  bool isBaselineReady(TelemetryBaseline baseline) {
    return baseline.active &&
        baseline.successRateMetricName.trim().isNotEmpty &&
        baseline.errorRateMetricName.trim().isNotEmpty &&
        baseline.rollbackAlertCondition.trim().isNotEmpty &&
        baseline.alertChannels.isNotEmpty;
  }

  RollbackTriggerEvaluation evaluateRollbackTrigger({
    required TelemetryBaseline baseline,
    required double successRatePercent,
    required double errorRatePercent,
    required DomainFailureCategory failureCategory,
  }) {
    if (!isBaselineReady(baseline)) {
      return const RollbackTriggerEvaluation(
        shouldTriggerRollback: false,
        reason: 'Telemetry baseline is not active.',
        triggerFailureCode: 'baseline-inactive',
      );
    }

    if (failureCategory.rollbackTrigger) {
      return RollbackTriggerEvaluation(
        shouldTriggerRollback: true,
        reason: 'Failure category requires rollback trigger handling.',
        triggerFailureCode: failureCategory.failureCode,
      );
    }

    if (!_evidencePolicy.regressionGatePassed(successRatePercent)) {
      return const RollbackTriggerEvaluation(
        shouldTriggerRollback: true,
        reason: 'Auth success rate dropped below migration threshold.',
        triggerFailureCode: 'success-rate-breach',
      );
    }

    final maxAllowedErrorRate = 100 - _evidencePolicy.minimumRegressionPassRatePercent;
    if (errorRatePercent > maxAllowedErrorRate) {
      return const RollbackTriggerEvaluation(
        shouldTriggerRollback: true,
        reason: 'Auth error rate exceeded migration threshold.',
        triggerFailureCode: 'error-rate-breach',
      );
    }

    return const RollbackTriggerEvaluation(
      shouldTriggerRollback: false,
      reason: 'No rollback trigger conditions met.',
      triggerFailureCode: 'none',
    );
  }

  bool postCutoverSlaPassed(int unresolvedCriticalRegressions) {
    return _evidencePolicy.postCutoverSlaPassed(unresolvedCriticalRegressions);
  }
}
