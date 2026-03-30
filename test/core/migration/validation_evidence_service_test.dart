import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/migration/migration.dart';

void main() {
  const policy = MigrationEvidencePolicy();
  const service = ValidationEvidenceService(policy);

  ValidationReport buildReport({
    required ValidationReportType type,
    required double passRate,
    required int criticalDefects,
  }) {
    return ValidationReport(
      reportId: '${type.wireValue}-1',
      sliceId: 'auth',
      reportType: type,
      passRatePercent: passRate,
      criticalOpenDefects: criticalDefects,
      evidenceRefs: const ['evidence://sample'],
      executedAt: DateTime.utc(2026, 3, 11),
      approvedBy: 'qa-team',
    );
  }

  test('marks readiness complete when all required evidence is present', () {
    final reports = [
      buildReport(
        type: ValidationReportType.regression,
        passRate: 98,
        criticalDefects: 0,
      ),
      buildReport(
        type: ValidationReportType.security,
        passRate: 100,
        criticalDefects: 0,
      ),
      buildReport(
        type: ValidationReportType.cutoverReadiness,
        passRate: 100,
        criticalDefects: 0,
      ),
      buildReport(
        type: ValidationReportType.postCutover,
        passRate: 100,
        criticalDefects: 0,
      ),
    ];

    final assessment = service.assess(
      reports: reports,
      telemetryBaselineActive: true,
      rollbackReadinessConfirmed: true,
      unresolvedCriticalDefects: 0,
    );

    expect(assessment.readyForValidationComplete, isTrue);
    expect(assessment.readyForCutover, isTrue);
    expect(assessment.readyForLegacyRemoval, isTrue);
  });

  test('fails validation readiness when regression evidence is below threshold', () {
    final reports = [
      buildReport(
        type: ValidationReportType.regression,
        passRate: 90,
        criticalDefects: 0,
      ),
      buildReport(
        type: ValidationReportType.security,
        passRate: 100,
        criticalDefects: 0,
      ),
    ];

    final assessment = service.assess(
      reports: reports,
      telemetryBaselineActive: true,
      rollbackReadinessConfirmed: true,
      unresolvedCriticalDefects: 0,
    );

    expect(assessment.readyForValidationComplete, isFalse);
    expect(assessment.readyForCutover, isFalse);
  });
}
