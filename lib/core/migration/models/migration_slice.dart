import 'migration_lifecycle.dart';

class MigrationSlice {
  final String sliceId;
  final String featureName;
  final String scopeDescription;
  final List<String> outOfScopeFlows;
  final MigrationState state;
  final bool noDowntimeRequired;
  final String rollbackPlanRef;
  final bool securityEvidenceRequired;
  final bool observabilityBaselineRequired;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MigrationSlice({
    required this.sliceId,
    required this.featureName,
    required this.scopeDescription,
    required this.outOfScopeFlows,
    required this.state,
    required this.noDowntimeRequired,
    required this.rollbackPlanRef,
    required this.securityEvidenceRequired,
    required this.observabilityBaselineRequired,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MigrationSlice.authDefault({
    DateTime? now,
    String sliceId = 'auth',
    String scopeDescription = 'Auth feature clean-architecture migration slice.',
  }) {
    final createdAt = now ?? DateTime.now().toUtc();
    return MigrationSlice(
      sliceId: sliceId,
      featureName: 'auth',
      scopeDescription: scopeDescription,
      outOfScopeFlows: const [
        'feed',
        'profile',
        'session',
        'social',
        'notifications',
      ],
      state: MigrationState.notStarted,
      noDowntimeRequired: true,
      rollbackPlanRef: 'AUTH-ROLLBACK-PLAYBOOK',
      securityEvidenceRequired: true,
      observabilityBaselineRequired: true,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  MigrationSlice copyWith({
    String? sliceId,
    String? featureName,
    String? scopeDescription,
    List<String>? outOfScopeFlows,
    MigrationState? state,
    bool? noDowntimeRequired,
    String? rollbackPlanRef,
    bool? securityEvidenceRequired,
    bool? observabilityBaselineRequired,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MigrationSlice(
      sliceId: sliceId ?? this.sliceId,
      featureName: featureName ?? this.featureName,
      scopeDescription: scopeDescription ?? this.scopeDescription,
      outOfScopeFlows: outOfScopeFlows ?? this.outOfScopeFlows,
      state: state ?? this.state,
      noDowntimeRequired: noDowntimeRequired ?? this.noDowntimeRequired,
      rollbackPlanRef: rollbackPlanRef ?? this.rollbackPlanRef,
      securityEvidenceRequired:
          securityEvidenceRequired ?? this.securityEvidenceRequired,
      observabilityBaselineRequired:
          observabilityBaselineRequired ?? this.observabilityBaselineRequired,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sliceId': sliceId,
      'featureName': featureName,
      'scopeDescription': scopeDescription,
      'outOfScopeFlows': outOfScopeFlows,
      'state': state.wireValue,
      'noDowntimeRequired': noDowntimeRequired,
      'rollbackPlanRef': rollbackPlanRef,
      'securityEvidenceRequired': securityEvidenceRequired,
      'observabilityBaselineRequired': observabilityBaselineRequired,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MigrationSlice.fromMap(Map<String, dynamic> map) {
    return MigrationSlice(
      sliceId: map['sliceId'] as String,
      featureName: map['featureName'] as String,
      scopeDescription: map['scopeDescription'] as String,
      outOfScopeFlows: (map['outOfScopeFlows'] as List<dynamic>)
          .map((value) => value.toString())
          .toList(growable: false),
      state: MigrationStateX.fromWireValue(map['state'] as String),
      noDowntimeRequired: map['noDowntimeRequired'] as bool? ?? true,
      rollbackPlanRef: map['rollbackPlanRef'] as String,
      securityEvidenceRequired: map['securityEvidenceRequired'] as bool? ?? true,
      observabilityBaselineRequired:
          map['observabilityBaselineRequired'] as bool? ?? true,
      createdAt: DateTime.parse(map['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(map['updatedAt'] as String).toUtc(),
    );
  }
}
