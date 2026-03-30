import 'migration_lifecycle.dart';

class MigrationBacklogItem {
  final String backlogItemId;
  final String sourceSliceId;
  final String targetFeatureName;
  final String description;
  final BacklogPriority priority;
  final BacklogStatus status;

  const MigrationBacklogItem({
    required this.backlogItemId,
    required this.sourceSliceId,
    required this.targetFeatureName,
    required this.description,
    required this.priority,
    required this.status,
  });

  MigrationBacklogItem copyWith({
    String? backlogItemId,
    String? sourceSliceId,
    String? targetFeatureName,
    String? description,
    BacklogPriority? priority,
    BacklogStatus? status,
  }) {
    return MigrationBacklogItem(
      backlogItemId: backlogItemId ?? this.backlogItemId,
      sourceSliceId: sourceSliceId ?? this.sourceSliceId,
      targetFeatureName: targetFeatureName ?? this.targetFeatureName,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'backlogItemId': backlogItemId,
      'sourceSliceId': sourceSliceId,
      'targetFeatureName': targetFeatureName,
      'description': description,
      'priority': priority.wireValue,
      'status': status.wireValue,
    };
  }

  factory MigrationBacklogItem.fromMap(Map<String, dynamic> map) {
    return MigrationBacklogItem(
      backlogItemId: map['backlogItemId'] as String,
      sourceSliceId: map['sourceSliceId'] as String,
      targetFeatureName: map['targetFeatureName'] as String,
      description: map['description'] as String,
      priority: BacklogPriorityX.fromWireValue(map['priority'] as String),
      status: BacklogStatusX.fromWireValue(map['status'] as String),
    );
  }
}
