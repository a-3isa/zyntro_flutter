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

/// Average speed in km/h — the cardio progress metric this scorer compares
/// against a user's own personal best.
///
/// [distanceKm] is a distance in kilometres (the unit `SessionSummary.distance`
/// and `ParticipantProgress.totalDistance` both carry). Returns `null` when
/// either input is non-positive, so a session with no logged distance or a
/// zero-length clock yields no speed rather than 0.0 or a division blow-up —
/// `computeWorkoutScore` skips a null/zero speed entirely.
double? averageSpeedKmh({
  required double distanceKm,
  required Duration elapsed,
}) {
  if (distanceKm <= 0 || elapsed.inSeconds <= 0) return null;
  return distanceKm / (elapsed.inSeconds / 3600);
}

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
    // Floor at 0: totalSets is unvalidated, and a negative would otherwise
    // produce negative effort points and drag the total below zero.
    final totalSets = math.max(0, summary?.totalSets ?? 0);
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
      // A 0-weight (bodyweight) or negative estimate carries no comparable
      // signal: storing it as a PR would make every later session on this
      // exercise re-trigger the "first time ever" branch forever (0 <= 0) and
      // pay the flat bonus regardless of actual rep improvement. Skip the
      // exercise entirely — no averaging contribution, no PR write.
      if (todayEstimate <= 0) continue;
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
    // Same rule as strength: a non-positive speed is not a comparable record
    // and must never be stored as a PR (it would be unbeatable-by-tie forever).
    if (activityType != null && todaySpeed != null && todaySpeed > 0) {
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

  // The caller feeds this straight into FieldValue.increment, so a negative
  // total would subtract from the user's stored leaderboard score.
  final total = math.max(
    0,
    (timePoints + buddyBonus + effortPoints + progressBonus).round(),
  );

  return WorkoutScoreResult(
    score: total,
    updatedStrengthPrs: updatedStrengthPrs,
    updatedCardioPrs: updatedCardioPrs,
  );
}
