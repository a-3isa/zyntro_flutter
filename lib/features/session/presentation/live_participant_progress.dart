/// Live, in-memory progress for one participant of an active session.
///
/// Distinct from [ParticipantProgress] in core/models, which is the persisted
/// document shape (sessionId, userId, workoutType, status, metric sub-objects).
/// This is the session room's own view model: what the UI needs to render the
/// current set, running totals and last logged values while the session is in
/// progress.
///
/// The two used to share the name `ParticipantProgress`, with this one declared
/// inside session_room_page.dart. Because a locally declared class shadows an
/// imported one, the page's reference silently resolved to this rather than the
/// model it imported from core/models — a trap for anyone reading either file.
class LiveParticipantProgress {
  final String currentExercise;
  final int totalSets;
  final double totalVolume;
  final DateTime? lastActivity;
  // Weight/reps/duration of the most recently logged set (gym only).
  final double? lastWeight;
  final int? lastReps;
  final int? lastSetSeconds;
  // Cardio-specific metrics
  final double totalDistance; // in km
  final int totalDuration; // in minutes
  final String? averagePace; // e.g., "5:30/km"
  final String? activityType; // 'running' or 'cycling'

  const LiveParticipantProgress({
    this.currentExercise = '',
    this.totalSets = 0,
    this.totalVolume = 0,
    this.lastActivity,
    this.lastWeight,
    this.lastReps,
    this.lastSetSeconds,
    this.totalDistance = 0,
    this.totalDuration = 0,
    this.averagePace,
    this.activityType,
  });

  /// Check if participant is active (logged set in last 2 minutes).
  bool get isActive {
    if (lastActivity == null) return false;
    return DateTime.now().difference(lastActivity!).inMinutes < 2;
  }

  LiveParticipantProgress copyWith({
    String? currentExercise,
    int? totalSets,
    double? totalVolume,
    DateTime? lastActivity,
    double? lastWeight,
    int? lastReps,
    int? lastSetSeconds,
    double? totalDistance,
    int? totalDuration,
    String? averagePace,
    String? activityType,
  }) {
    return LiveParticipantProgress(
      currentExercise: currentExercise ?? this.currentExercise,
      totalSets: totalSets ?? this.totalSets,
      totalVolume: totalVolume ?? this.totalVolume,
      lastActivity: lastActivity ?? this.lastActivity,
      lastWeight: lastWeight ?? this.lastWeight,
      lastReps: lastReps ?? this.lastReps,
      lastSetSeconds: lastSetSeconds ?? this.lastSetSeconds,
      totalDistance: totalDistance ?? this.totalDistance,
      totalDuration: totalDuration ?? this.totalDuration,
      averagePace: averagePace ?? this.averagePace,
      activityType: activityType ?? this.activityType,
    );
  }
}
