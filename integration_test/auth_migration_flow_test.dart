import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/migration/migration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MigrationGovernanceRepository repository;

  setUp(() {
    const guard = MigrationTransitionGuard();
    const policy = MigrationEvidencePolicy();
    const stateMachine = MigrationStateMachine(guard);
    const evidenceService = ValidationEvidenceService(policy);

    repository = MigrationGovernanceRepository(
      stateMachine: stateMachine,
      validationEvidenceService: evidenceService,
    );
  });

  testWidgets('executes auth migration lifecycle with cutover and rollback readiness', (
    tester,
  ) async {
    final slice = await repository.getOrCreateAuthSlice();
    expect(slice.featureName, 'auth');
    expect(slice.noDowntimeRequired, isTrue);
    expect(slice.state, MigrationState.notStarted);

    final inProgress = await repository.transitionSliceState(
      sliceId: slice.sliceId,
      toState: MigrationState.inProgress,
      reason: 'Begin auth migration',
    );
    expect(inProgress.state, MigrationState.inProgress);

    await repository.addValidationReport(
      ValidationReport(
        reportId: 'regression-1',
        sliceId: slice.sliceId,
        reportType: ValidationReportType.regression,
        passRatePercent: 98,
        criticalOpenDefects: 0,
        evidenceRefs: const ['regression://auth'],
        executedAt: DateTime.utc(2026, 3, 11),
        approvedBy: 'qa',
      ),
    );
    await repository.addValidationReport(
      ValidationReport(
        reportId: 'security-1',
        sliceId: slice.sliceId,
        reportType: ValidationReportType.security,
        passRatePercent: 100,
        criticalOpenDefects: 0,
        evidenceRefs: const ['security://auth'],
        executedAt: DateTime.utc(2026, 3, 11),
        approvedBy: 'security',
      ),
    );
    await repository.addValidationReport(
      ValidationReport(
        reportId: 'cutover-1',
        sliceId: slice.sliceId,
        reportType: ValidationReportType.cutoverReadiness,
        passRatePercent: 100,
        criticalOpenDefects: 0,
        evidenceRefs: const ['cutover://auth'],
        executedAt: DateTime.utc(2026, 3, 11),
        approvedBy: 'release-manager',
      ),
    );

    await repository.upsertTelemetryBaseline(
      const TelemetryBaseline(
        baselineId: 'telemetry-1',
        sliceId: 'auth',
        successRateMetricName: 'auth_success_rate',
        errorRateMetricName: 'auth_error_rate',
        rollbackAlertCondition: 'error_rate > 5',
        alertChannels: ['pagerduty'],
        active: true,
      ),
    );

    final validationComplete = await repository.transitionSliceState(
      sliceId: slice.sliceId,
      toState: MigrationState.validationComplete,
      reason: 'Validation criteria met',
    );
    expect(validationComplete.state, MigrationState.validationComplete);

    final cutoverDecision = await repository.requestCutover(
      sliceId: slice.sliceId,
      requestedBy: 'release-manager',
      changeReference: 'CHG-2026-0311',
    );
    expect(cutoverDecision.accepted, isTrue);
    expect(cutoverDecision.slice?.state, MigrationState.cutoverComplete);

    await repository.addValidationReport(
      ValidationReport(
        reportId: 'post-cutover-1',
        sliceId: slice.sliceId,
        reportType: ValidationReportType.postCutover,
        passRatePercent: 100,
        criticalOpenDefects: 0,
        evidenceRefs: const ['post-cutover://auth'],
        executedAt: DateTime.utc(2026, 3, 11),
        approvedBy: 'ops',
      ),
    );

    final legacyRemoved = await repository.transitionSliceState(
      sliceId: slice.sliceId,
      toState: MigrationState.legacyRemoved,
      reason: 'Post-cutover checks complete',
    );

    expect(legacyRemoved.state, MigrationState.legacyRemoved);
  });
}
