import '../models/migration_lifecycle.dart';
import '../models/validation_report.dart';
import 'migration_evidence_policy.dart';
import 'migration_transition_guard.dart';

class ValidationGateAssessment {
  final bool hasRegressionEvidence;
  final bool hasSecurityEvidence;
  final bool hasCutoverReadinessEvidence;
  final bool hasPostCutoverEvidence;
  final bool telemetryBaselineActive;
  final bool rollbackReadinessConfirmed;
  final int unresolvedCriticalDefects;

  const ValidationGateAssessment({
    required this.hasRegressionEvidence,
    required this.hasSecurityEvidence,
    required this.hasCutoverReadinessEvidence,
    required this.hasPostCutoverEvidence,
    required this.telemetryBaselineActive,
    required this.rollbackReadinessConfirmed,
    required this.unresolvedCriticalDefects,
  });

  bool get readyForValidationComplete =>
      hasRegressionEvidence && hasSecurityEvidence;

  bool get readyForCutover =>
      readyForValidationComplete &&
      hasCutoverReadinessEvidence &&
      telemetryBaselineActive &&
      rollbackReadinessConfirmed;

  bool get readyForLegacyRemoval =>
      readyForCutover && hasPostCutoverEvidence && unresolvedCriticalDefects == 0;

  TransitionPrerequisites toTransitionPrerequisites() {
    return TransitionPrerequisites(
      hasRegressionEvidence: hasRegressionEvidence,
      hasSecurityEvidence: hasSecurityEvidence,
      telemetryBaselineActive: telemetryBaselineActive,
      rollbackReadinessConfirmed: rollbackReadinessConfirmed,
      hasPostCutoverEvidence: hasPostCutoverEvidence,
      unresolvedCriticalDefects: unresolvedCriticalDefects,
    );
  }
}

class ValidationEvidenceService {
  final MigrationEvidencePolicy _policy;

  const ValidationEvidenceService(this._policy);

  ValidationGateAssessment assess({
    required List<ValidationReport> reports,
    required bool telemetryBaselineActive,
    required bool rollbackReadinessConfirmed,
    required int unresolvedCriticalDefects,
  }) {
    final hasRegressionEvidence = reports.any(
      (report) =>
          report.reportType == ValidationReportType.regression &&
          _policy.regressionGatePassed(report.passRatePercent),
    );

    final hasSecurityEvidence = reports.any(
      (report) =>
          report.reportType == ValidationReportType.security &&
          _policy.securityGatePassed(report.criticalOpenDefects),
    );

    final hasCutoverReadinessEvidence = reports.any(
      (report) =>
          report.reportType == ValidationReportType.cutoverReadiness &&
          _policy.securityGatePassed(report.criticalOpenDefects),
    );

    final hasPostCutoverEvidence = reports.any(
      (report) =>
          report.reportType == ValidationReportType.postCutover &&
          _policy.securityGatePassed(report.criticalOpenDefects),
    );

    return ValidationGateAssessment(
      hasRegressionEvidence: hasRegressionEvidence,
      hasSecurityEvidence: hasSecurityEvidence,
      hasCutoverReadinessEvidence: hasCutoverReadinessEvidence,
      hasPostCutoverEvidence: hasPostCutoverEvidence,
      telemetryBaselineActive: telemetryBaselineActive,
      rollbackReadinessConfirmed: rollbackReadinessConfirmed,
      unresolvedCriticalDefects: unresolvedCriticalDefects,
    );
  }
}
