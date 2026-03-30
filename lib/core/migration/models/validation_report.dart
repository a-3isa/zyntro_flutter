import 'migration_lifecycle.dart';

class ValidationReport {
  final String reportId;
  final String sliceId;
  final ValidationReportType reportType;
  final double passRatePercent;
  final int criticalOpenDefects;
  final List<String> evidenceRefs;
  final DateTime executedAt;
  final String approvedBy;

  const ValidationReport({
    required this.reportId,
    required this.sliceId,
    required this.reportType,
    required this.passRatePercent,
    required this.criticalOpenDefects,
    required this.evidenceRefs,
    required this.executedAt,
    required this.approvedBy,
  });

  bool passes({
    double minimumRegressionPassRatePercent = 95,
    int maximumCriticalOpenDefects = 0,
  }) {
    switch (reportType) {
      case ValidationReportType.regression:
        return passRatePercent >= minimumRegressionPassRatePercent;
      case ValidationReportType.security:
      case ValidationReportType.cutoverReadiness:
      case ValidationReportType.postCutover:
        return criticalOpenDefects <= maximumCriticalOpenDefects;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'sliceId': sliceId,
      'reportType': reportType.wireValue,
      'passRatePercent': passRatePercent,
      'criticalOpenDefects': criticalOpenDefects,
      'evidenceRefs': evidenceRefs,
      'executedAt': executedAt.toIso8601String(),
      'approvedBy': approvedBy,
    };
  }

  factory ValidationReport.fromMap(Map<String, dynamic> map) {
    return ValidationReport(
      reportId: map['reportId'] as String,
      sliceId: map['sliceId'] as String,
      reportType: ValidationReportTypeX.fromWireValue(
        map['reportType'] as String,
      ),
      passRatePercent: (map['passRatePercent'] as num).toDouble(),
      criticalOpenDefects: map['criticalOpenDefects'] as int,
      evidenceRefs: (map['evidenceRefs'] as List<dynamic>)
          .map((value) => value.toString())
          .toList(growable: false),
      executedAt: DateTime.parse(map['executedAt'] as String).toUtc(),
      approvedBy: map['approvedBy'] as String,
    );
  }
}
