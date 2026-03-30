class TelemetryBaseline {
  final String baselineId;
  final String sliceId;
  final String successRateMetricName;
  final String errorRateMetricName;
  final String rollbackAlertCondition;
  final List<String> alertChannels;
  final bool active;

  const TelemetryBaseline({
    required this.baselineId,
    required this.sliceId,
    required this.successRateMetricName,
    required this.errorRateMetricName,
    required this.rollbackAlertCondition,
    required this.alertChannels,
    required this.active,
  });

  Map<String, dynamic> toMap() {
    return {
      'baselineId': baselineId,
      'sliceId': sliceId,
      'successRateMetricName': successRateMetricName,
      'errorRateMetricName': errorRateMetricName,
      'rollbackAlertCondition': rollbackAlertCondition,
      'alertChannels': alertChannels,
      'active': active,
    };
  }

  factory TelemetryBaseline.fromMap(Map<String, dynamic> map) {
    return TelemetryBaseline(
      baselineId: map['baselineId'] as String,
      sliceId: map['sliceId'] as String,
      successRateMetricName: map['successRateMetricName'] as String,
      errorRateMetricName: map['errorRateMetricName'] as String,
      rollbackAlertCondition: map['rollbackAlertCondition'] as String,
      alertChannels: (map['alertChannels'] as List<dynamic>)
          .map((value) => value.toString())
          .toList(growable: false),
      active: map['active'] as bool? ?? false,
    );
  }
}
