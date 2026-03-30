class RollbackEvent {
  final String rollbackEventId;
  final String sliceId;
  final String triggerFailureCode;
  final DateTime triggeredAt;
  final String actionSummary;
  final DateTime? resolvedAt;

  const RollbackEvent({
    required this.rollbackEventId,
    required this.sliceId,
    required this.triggerFailureCode,
    required this.triggeredAt,
    required this.actionSummary,
    this.resolvedAt,
  });

  RollbackEvent copyWith({
    String? rollbackEventId,
    String? sliceId,
    String? triggerFailureCode,
    DateTime? triggeredAt,
    String? actionSummary,
    DateTime? resolvedAt,
  }) {
    return RollbackEvent(
      rollbackEventId: rollbackEventId ?? this.rollbackEventId,
      sliceId: sliceId ?? this.sliceId,
      triggerFailureCode: triggerFailureCode ?? this.triggerFailureCode,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      actionSummary: actionSummary ?? this.actionSummary,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rollbackEventId': rollbackEventId,
      'sliceId': sliceId,
      'triggerFailureCode': triggerFailureCode,
      'triggeredAt': triggeredAt.toIso8601String(),
      'actionSummary': actionSummary,
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }

  factory RollbackEvent.fromMap(Map<String, dynamic> map) {
    return RollbackEvent(
      rollbackEventId: map['rollbackEventId'] as String,
      sliceId: map['sliceId'] as String,
      triggerFailureCode: map['triggerFailureCode'] as String,
      triggeredAt: DateTime.parse(map['triggeredAt'] as String).toUtc(),
      actionSummary: map['actionSummary'] as String,
      resolvedAt: map['resolvedAt'] == null
          ? null
          : DateTime.parse(map['resolvedAt'] as String).toUtc(),
    );
  }
}
