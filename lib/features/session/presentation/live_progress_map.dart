import 'live_participant_progress.dart';

/// Parses the session-progress service map into live UI models (Z-ARCH-002).
Map<String, LiveParticipantProgress> liveProgressFromServiceMap(
  Map<String, dynamic> data,
) {
  final newProgress = <String, LiveParticipantProgress>{};

  data.forEach((userId, stats) {
    if (stats is! Map<String, dynamic>) return;

    DateTime? lastActivity;
    if (stats['lastActivity'] != null) {
      try {
        lastActivity = DateTime.parse(stats['lastActivity'] as String);
      } catch (_) {}
    }

    newProgress[userId] = LiveParticipantProgress(
      currentExercise: stats['currentExercise'] as String? ?? '',
      totalSets: stats['totalSets'] as int? ?? 0,
      totalVolume: (stats['totalVolume'] as num?)?.toDouble() ?? 0.0,
      lastWeight: (stats['lastWeight'] as num?)?.toDouble(),
      lastReps: stats['lastReps'] as int?,
      lastSetSeconds: stats['lastSetSeconds'] as int?,
      totalDistance: (stats['totalDistance'] as num?)?.toDouble() ?? 0.0,
      totalDuration: stats['totalDuration'] as int? ?? 0,
      averagePace: stats['averagePace'] as String?,
      activityType: stats['activityType'] as String?,
      lastActivity: lastActivity,
    );
  });

  return newProgress;
}
