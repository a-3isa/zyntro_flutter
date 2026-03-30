enum MigrationState {
  notStarted,
  inProgress,
  validationComplete,
  cutoverComplete,
  legacyRemoved,
}

extension MigrationStateX on MigrationState {
  String get wireValue => switch (this) {
    MigrationState.notStarted => 'NOT_STARTED',
    MigrationState.inProgress => 'IN_PROGRESS',
    MigrationState.validationComplete => 'VALIDATION_COMPLETE',
    MigrationState.cutoverComplete => 'CUTOVER_COMPLETE',
    MigrationState.legacyRemoved => 'LEGACY_REMOVED',
  };

  String get label => switch (this) {
    MigrationState.notStarted => 'Not Started',
    MigrationState.inProgress => 'In Progress',
    MigrationState.validationComplete => 'Validation Complete',
    MigrationState.cutoverComplete => 'Cutover Complete',
    MigrationState.legacyRemoved => 'Legacy Removed',
  };

  static MigrationState fromWireValue(String value) {
    return switch (value) {
      'NOT_STARTED' => MigrationState.notStarted,
      'IN_PROGRESS' => MigrationState.inProgress,
      'VALIDATION_COMPLETE' => MigrationState.validationComplete,
      'CUTOVER_COMPLETE' => MigrationState.cutoverComplete,
      'LEGACY_REMOVED' => MigrationState.legacyRemoved,
      _ => throw ArgumentError('Unknown migration state: $value'),
    };
  }
}

enum ValidationReportType {
  regression,
  security,
  cutoverReadiness,
  postCutover,
}

extension ValidationReportTypeX on ValidationReportType {
  String get wireValue => switch (this) {
    ValidationReportType.regression => 'REGRESSION',
    ValidationReportType.security => 'SECURITY',
    ValidationReportType.cutoverReadiness => 'CUTOVER_READINESS',
    ValidationReportType.postCutover => 'POST_CUTOVER',
  };

  static ValidationReportType fromWireValue(String value) {
    return switch (value) {
      'REGRESSION' => ValidationReportType.regression,
      'SECURITY' => ValidationReportType.security,
      'CUTOVER_READINESS' => ValidationReportType.cutoverReadiness,
      'POST_CUTOVER' => ValidationReportType.postCutover,
      _ => throw ArgumentError('Unknown validation report type: $value'),
    };
  }
}

enum LayerBoundary { presentationDomain, domainData, dataDataSource }

extension LayerBoundaryX on LayerBoundary {
  String get wireValue => switch (this) {
    LayerBoundary.presentationDomain => 'PRESENTATION_DOMAIN',
    LayerBoundary.domainData => 'DOMAIN_DATA',
    LayerBoundary.dataDataSource => 'DATA_DATASOURCE',
  };

  static LayerBoundary fromWireValue(String value) {
    return switch (value) {
      'PRESENTATION_DOMAIN' => LayerBoundary.presentationDomain,
      'DOMAIN_DATA' => LayerBoundary.domainData,
      'DATA_DATASOURCE' => LayerBoundary.dataDataSource,
      _ => throw ArgumentError('Unknown layer boundary: $value'),
    };
  }
}

enum FailureSeverity { low, medium, high, critical }

extension FailureSeverityX on FailureSeverity {
  String get wireValue => switch (this) {
    FailureSeverity.low => 'LOW',
    FailureSeverity.medium => 'MEDIUM',
    FailureSeverity.high => 'HIGH',
    FailureSeverity.critical => 'CRITICAL',
  };

  static FailureSeverity fromWireValue(String value) {
    return switch (value) {
      'LOW' => FailureSeverity.low,
      'MEDIUM' => FailureSeverity.medium,
      'HIGH' => FailureSeverity.high,
      'CRITICAL' => FailureSeverity.critical,
      _ => throw ArgumentError('Unknown failure severity: $value'),
    };
  }
}

enum BacklogPriority { p1, p2, p3 }

extension BacklogPriorityX on BacklogPriority {
  String get wireValue => switch (this) {
    BacklogPriority.p1 => 'P1',
    BacklogPriority.p2 => 'P2',
    BacklogPriority.p3 => 'P3',
  };

  static BacklogPriority fromWireValue(String value) {
    return switch (value) {
      'P1' => BacklogPriority.p1,
      'P2' => BacklogPriority.p2,
      'P3' => BacklogPriority.p3,
      _ => throw ArgumentError('Unknown backlog priority: $value'),
    };
  }
}

enum BacklogStatus { open, scheduled, done }

extension BacklogStatusX on BacklogStatus {
  String get wireValue => switch (this) {
    BacklogStatus.open => 'OPEN',
    BacklogStatus.scheduled => 'SCHEDULED',
    BacklogStatus.done => 'DONE',
  };

  static BacklogStatus fromWireValue(String value) {
    return switch (value) {
      'OPEN' => BacklogStatus.open,
      'SCHEDULED' => BacklogStatus.scheduled,
      'DONE' => BacklogStatus.done,
      _ => throw ArgumentError('Unknown backlog status: $value'),
    };
  }
}

class MigrationTransition {
  final MigrationState fromState;
  final MigrationState toState;
  final String reason;
  final DateTime occurredAt;

  const MigrationTransition({
    required this.fromState,
    required this.toState,
    required this.reason,
    required this.occurredAt,
  });
}
