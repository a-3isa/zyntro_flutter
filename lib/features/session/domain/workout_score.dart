// lib/features/session/domain/workout_score.dart
import 'dart:math' as math;

import '../../../core/models/models.dart';

class WorkoutScoreResult {
  final int score;
  final Map<String, double> updatedStrengthPrs;
  final Map<String, double> updatedCardioPrs;

  const WorkoutScoreResult({
    required this.score,
    required this.updatedStrengthPrs,
    required this.updatedCardioPrs,
  });
}

const int _timeCapMinutes = 60;
const int _buddyBonusPoints = 15;
const int _effortPointsPerSet = 2;
const int _effortSetCap = 20;
const double _progressFloor = 0.0;
const double _progressCap = 0.20;
const double _firstTimeBonusPct = 0.05;
const double _progressPointsMultiplier = 800;

double _epleyEstimate(double weight, int reps) => weight * (1 + reps / 30);

WorkoutScoreResult computeWorkoutScore({
  required Duration sessionDuration,
  required bool hasRealHumanBuddy,
  required String sessionType,
  required SessionSummary? summary,
  required Map<String, double> currentStrengthPrs,
  required Map<String, double> currentCardioPrs,
}) {
  final timePoints = math
      .max(0, math.min(sessionDuration.inMinutes, _timeCapMinutes));
  final buddyBonus = hasRealHumanBuddy ? _buddyBonusPoints : 0;

  var effortPoints = 0;
  if (sessionType == 'strength') {
    final totalSets = summary?.totalSets ?? 0;
    effortPoints = math.min(totalSets, _effortSetCap) * _effortPointsPerSet;
  }

  final updatedStrengthPrs = <String, double>{};
  final updatedCardioPrs = <String, double>{};
  final pctImprovements = <double>[];

  if (sessionType == 'strength') {
    for (final exercise in summary?.exercises ?? const <ExerciseSummary>[]) {
      if (exercise.setDetails.isEmpty) continue;
      final key = exercise.name.toLowerCase();
      final todayEstimate = exercise.setDetails
          .map((s) => _epleyEstimate(s.weight, s.reps))
          .reduce(math.max);
      final personalBest = currentStrengthPrs[key];

      double pct;
      if (personalBest == null || personalBest <= 0) {
        pct = _firstTimeBonusPct;
        updatedStrengthPrs[key] = todayEstimate;
      } else {
        final raw = (todayEstimate - personalBest) / personalBest;
        pct = raw.clamp(_progressFloor, _progressCap);
        if (todayEstimate > personalBest) {
          updatedStrengthPrs[key] = todayEstimate;
        }
      }
      pctImprovements.add(pct);
    }
  } else if (sessionType == 'cardio') {
    final activityType = summary?.activityType;
    final todaySpeed = summary?.averageSpeed;
    if (activityType != null && todaySpeed != null) {
      final personalBest = currentCardioPrs[activityType];
      double pct;
      if (personalBest == null || personalBest <= 0) {
        pct = _firstTimeBonusPct;
        updatedCardioPrs[activityType] = todaySpeed;
      } else {
        final raw = (todaySpeed - personalBest) / personalBest;
        pct = raw.clamp(_progressFloor, _progressCap);
        if (todaySpeed > personalBest) {
          updatedCardioPrs[activityType] = todaySpeed;
        }
      }
      pctImprovements.add(pct);
    }
  }

  final averagePct = pctImprovements.isEmpty
      ? 0.0
      : pctImprovements.reduce((a, b) => a + b) / pctImprovements.length;
  final progressBonus = averagePct * _progressPointsMultiplier;

  final total =
      (timePoints + buddyBonus + effortPoints + progressBonus).round();

  return WorkoutScoreResult(
    score: total,
    updatedStrengthPrs: updatedStrengthPrs,
    updatedCardioPrs: updatedCardioPrs,
  );
}
