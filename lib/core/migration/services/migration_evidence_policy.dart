class MigrationEvidencePolicy {
  final double minimumRegressionPassRatePercent;
  final int maxCriticalOpenDefectsAtCutover;
  final int maxCriticalRegressionsAfterCutover;

  const MigrationEvidencePolicy({
    this.minimumRegressionPassRatePercent = 95,
    this.maxCriticalOpenDefectsAtCutover = 0,
    this.maxCriticalRegressionsAfterCutover = 0,
  });

  bool regressionGatePassed(double passRatePercent) {
    return passRatePercent >= minimumRegressionPassRatePercent;
  }

  bool securityGatePassed(int criticalOpenDefects) {
    return criticalOpenDefects <= maxCriticalOpenDefectsAtCutover;
  }

  bool cutoverOperationalGatePassed({
    required bool telemetryBaselineActive,
    required bool rollbackReadinessConfirmed,
  }) {
    return telemetryBaselineActive && rollbackReadinessConfirmed;
  }

  bool postCutoverSlaPassed(int unresolvedCriticalRegressions) {
    return unresolvedCriticalRegressions <= maxCriticalRegressionsAfterCutover;
  }
}
