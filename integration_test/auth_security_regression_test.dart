import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/migration/migration.dart';
import 'package:zyntro_flutter/features/auth/domain/failures/auth_failure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MigrationGovernanceRepository repository;
  late DomainFailureCategoryMapper mapper;
  late TelemetryBaselineService telemetryService;

  setUp(() {
    const guard = MigrationTransitionGuard();
    const policy = MigrationEvidencePolicy();
    const stateMachine = MigrationStateMachine(guard);
    const evidenceService = ValidationEvidenceService(policy);

    repository = MigrationGovernanceRepository(
      stateMachine: stateMachine,
      validationEvidenceService: evidenceService,
    );
    mapper = const DomainFailureCategoryMapper();
    telemetryService = const TelemetryBaselineService(policy);
  });

  testWidgets('records security regression evidence and rollback triggers', (
    tester,
  ) async {
    final slice = await repository.getOrCreateAuthSlice();

    await repository.addValidationReport(
      ValidationReport(
        reportId: 'security-regression-1',
        sliceId: slice.sliceId,
        reportType: ValidationReportType.security,
        passRatePercent: 100,
        criticalOpenDefects: 0,
        evidenceRefs: const ['security://auth/authz/session'],
        executedAt: DateTime.utc(2026, 3, 11),
        approvedBy: 'security-team',
      ),
    );

    await repository.upsertTelemetryBaseline(
      const TelemetryBaseline(
        baselineId: 'telemetry-auth-1',
        sliceId: 'auth',
        successRateMetricName: 'auth_success_rate',
        errorRateMetricName: 'auth_error_rate',
        rollbackAlertCondition: 'security_events > 0',
        alertChannels: ['pagerduty', 'slack-security'],
        active: true,
      ),
    );

    final authnCategory = mapper.mapAuthFailure(
      const AuthFailure(
        message: 'Invalid credential.',
        code: 'invalid-credential',
      ),
    );
    final authzCategory = mapper.mapAuthFailure(
      const AuthFailure(
        message: 'Permission denied.',
        code: 'permission-denied',
      ),
    );
    final sessionCategory = mapper.mapAuthFailure(
      const AuthFailure(
        message: 'Session expired.',
        code: 'session-expired',
      ),
    );

    expect(authnCategory.categoryName, 'AUTHENTICATION');
    expect(authzCategory.categoryName, 'AUTHORIZATION');
    expect(sessionCategory.categoryName, 'SESSION');
    expect(authzCategory.rollbackTrigger, isTrue);
    expect(sessionCategory.rollbackTrigger, isTrue);

    final baseline = await repository.getTelemetryBaseline(slice.sliceId);
    expect(baseline, isNotNull);

    final evaluation = telemetryService.evaluateRollbackTrigger(
      baseline: baseline!,
      successRatePercent: 99,
      errorRatePercent: 1,
      failureCategory: authzCategory,
    );

    expect(evaluation.shouldTriggerRollback, isTrue);

    await repository.addRollbackEvent(
      sliceId: slice.sliceId,
      triggerFailureCode: evaluation.triggerFailureCode,
      actionSummary: 'Security regression rollback trigger evidence captured',
    );

    final rollbackEvents = await repository.getRollbackEvents(slice.sliceId);
    expect(rollbackEvents, hasLength(1));
    expect(rollbackEvents.first.triggerFailureCode, 'authorization');
  });
}
