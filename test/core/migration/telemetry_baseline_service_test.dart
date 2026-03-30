import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/migration/migration.dart';

void main() {
  const service = TelemetryBaselineService(MigrationEvidencePolicy());

  const baseline = TelemetryBaseline(
    baselineId: 'baseline-1',
    sliceId: 'auth',
    successRateMetricName: 'auth_success_rate',
    errorRateMetricName: 'auth_error_rate',
    rollbackAlertCondition: 'error_rate > 5',
    alertChannels: ['pagerduty'],
    active: true,
  );

  test('validates telemetry baseline readiness', () {
    expect(service.isBaselineReady(baseline), isTrue);
  });

  test('triggers rollback when failure category requires it', () {
    const category = DomainFailureCategory(
      failureCode: 'authorization',
      categoryName: 'AUTHORIZATION',
      userMessage: 'Permission denied.',
      severity: FailureSeverity.high,
      rollbackTrigger: true,
    );

    final evaluation = service.evaluateRollbackTrigger(
      baseline: baseline,
      successRatePercent: 99,
      errorRatePercent: 1,
      failureCategory: category,
    );

    expect(evaluation.shouldTriggerRollback, isTrue);
    expect(evaluation.triggerFailureCode, 'authorization');
  });

  test('triggers rollback when success rate drops below threshold', () {
    const category = DomainFailureCategory(
      failureCode: 'network',
      categoryName: 'EXTERNAL_DEPENDENCY',
      userMessage: 'Network issue.',
      severity: FailureSeverity.medium,
      rollbackTrigger: false,
    );

    final evaluation = service.evaluateRollbackTrigger(
      baseline: baseline,
      successRatePercent: 90,
      errorRatePercent: 10,
      failureCategory: category,
    );

    expect(evaluation.shouldTriggerRollback, isTrue);
    expect(evaluation.triggerFailureCode, 'success-rate-breach');
  });

  test('does not trigger rollback when telemetry signals are healthy', () {
    const category = DomainFailureCategory(
      failureCode: 'network',
      categoryName: 'EXTERNAL_DEPENDENCY',
      userMessage: 'Network issue.',
      severity: FailureSeverity.medium,
      rollbackTrigger: false,
    );

    final evaluation = service.evaluateRollbackTrigger(
      baseline: baseline,
      successRatePercent: 98,
      errorRatePercent: 2,
      failureCategory: category,
    );

    expect(evaluation.shouldTriggerRollback, isFalse);
  });
}
