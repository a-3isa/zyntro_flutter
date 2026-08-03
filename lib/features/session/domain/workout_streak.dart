/// Incremental streak maintenance.
///
/// Streak stats used to be recomputed by reading a user's entire completed
/// session history on every request — a read cost that grew with every workout
/// they ever logged. These stats are now maintained on the user document and
/// advanced by one session at a time, which makes reading them a single
/// document read no matter how long the history is.
///
/// This function is pure so the date arithmetic is directly testable without
/// Firestore, mirroring `workout_score.dart`.
library;

/// The stored streak state for a user, as held on their user document.
class StreakState {
  /// Consecutive days with at least one completed workout, counting back from
  /// [lastWorkoutDate].
  final int currentStreak;

  /// Longest [currentStreak] the user has ever reached.
  final int longestStreak;

  /// Local calendar date (`yyyy-MM-dd`) of the most recent completed workout,
  /// or null if the user has never completed one.
  final String? lastWorkoutDate;

  /// Completed sessions since [weekStartDate]. Counts sessions, not distinct
  /// days — two workouts on one day count twice here but once toward a streak.
  final int weeklyWorkouts;

  /// Local calendar date (`yyyy-MM-dd`) of the Monday that starts the week
  /// [weeklyWorkouts] is counting, or null if never set.
  final String? weekStartDate;

  const StreakState({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastWorkoutDate,
    this.weeklyWorkouts = 0,
    this.weekStartDate,
  });

  @override
  bool operator ==(Object other) =>
      other is StreakState &&
      other.currentStreak == currentStreak &&
      other.longestStreak == longestStreak &&
      other.lastWorkoutDate == lastWorkoutDate &&
      other.weeklyWorkouts == weeklyWorkouts &&
      other.weekStartDate == weekStartDate;

  @override
  int get hashCode => Object.hash(
    currentStreak,
    longestStreak,
    lastWorkoutDate,
    weeklyWorkouts,
    weekStartDate,
  );

  @override
  String toString() =>
      'StreakState(current: $currentStreak, longest: $longestStreak, '
      'last: $lastWorkoutDate, weekly: $weeklyWorkouts, week: $weekStartDate)';
}

/// Formats [date] as the local calendar day `yyyy-MM-dd`, discarding the time.
String calendarDay(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

/// The Monday that starts [date]'s week, as `yyyy-MM-dd`.
String weekStartFor(DateTime date) {
  final local = date.toLocal();
  final midnight = DateTime(local.year, local.month, local.day);
  return calendarDay(midnight.subtract(Duration(days: midnight.weekday - 1)));
}

/// Folds one completed workout at [completedAt] into [previous].
///
/// A second workout on a day the user already trained does not extend the
/// streak — a streak counts days, not sessions — but it does count toward
/// [StreakState.weeklyWorkouts], which counts sessions.
StreakState advanceStreak({
  required StreakState previous,
  required DateTime completedAt,
}) {
  final today = calendarDay(completedAt);
  final thisWeek = weekStartFor(completedAt);

  final weeklyWorkouts = previous.weekStartDate == thisWeek
      ? previous.weeklyWorkouts + 1
      : 1;

  final last = previous.lastWorkoutDate;

  // Same day: the day is already counted in the streak, so only the weekly
  // session tally moves.
  if (last == today) {
    return StreakState(
      currentStreak: previous.currentStreak,
      longestStreak: previous.longestStreak,
      lastWorkoutDate: last,
      weeklyWorkouts: weeklyWorkouts,
      weekStartDate: thisWeek,
    );
  }

  final int currentStreak;
  if (last == null) {
    currentStreak = 1;
  } else {
    final gap = DateTime.parse(today).difference(DateTime.parse(last)).inDays;
    // A workout backdated before the stored last date would produce a negative
    // gap; treat anything other than "the next day" as starting over rather
    // than trusting arithmetic on out-of-order input.
    currentStreak = gap == 1 ? previous.currentStreak + 1 : 1;
  }

  return StreakState(
    currentStreak: currentStreak,
    longestStreak: currentStreak > previous.longestStreak
        ? currentStreak
        : previous.longestStreak,
    lastWorkoutDate: today,
    weeklyWorkouts: weeklyWorkouts,
    weekStartDate: thisWeek,
  );
}

/// Reads a [StreakState] out of a user document's raw field map.
///
/// Tolerates missing and wrongly-typed fields: a user document written before
/// these counters existed simply yields a zeroed state with a null
/// [StreakState.lastWorkoutDate], which callers use to detect that the user
/// still needs backfilling.
StreakState streakStateFromUserData(Map<String, dynamic>? data) {
  if (data == null) return const StreakState();

  int readInt(String key) {
    final value = data[key];
    return value is num && value.isFinite ? value.toInt() : 0;
  }

  String? readDay(String key) {
    final value = data[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  return StreakState(
    currentStreak: readInt('currentStreak'),
    longestStreak: readInt('longestStreak'),
    lastWorkoutDate: readDay('lastWorkoutDate'),
    weeklyWorkouts: readInt('weeklyWorkouts'),
    weekStartDate: readDay('weekStartDate'),
  );
}
