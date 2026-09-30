import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/features/session/domain/workout_streak.dart';

void main() {
  group('calendarDay', () {
    test('pads month and day to two digits', () {
      expect(calendarDay(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
    });

    test('discards the time of day', () {
      expect(calendarDay(DateTime(2026, 12, 25, 0, 0)), '2026-12-25');
      expect(calendarDay(DateTime(2026, 12, 25, 23, 59)), '2026-12-25');
    });
  });

  group('weekStartFor', () {
    test('returns the same Monday for every day of that week', () {
      // 2026-08-03 is a Monday.
      for (var i = 0; i < 7; i++) {
        expect(
          weekStartFor(DateTime(2026, 8, 3).add(Duration(days: i))),
          '2026-08-03',
        );
      }
    });

    test('rolls to the next Monday on the following day', () {
      expect(weekStartFor(DateTime(2026, 8, 10)), '2026-08-10');
    });

    test('handles a Sunday as the end of the prior week', () {
      // 2026-08-09 is a Sunday.
      expect(weekStartFor(DateTime(2026, 8, 9)), '2026-08-03');
    });
  });

  group('advanceStreak', () {
    test('starts a streak at one for a first-ever workout', () {
      final next = advanceStreak(
        previous: const StreakState(),
        completedAt: DateTime(2026, 8, 3, 18),
      );

      expect(next.currentStreak, 1);
      expect(next.longestStreak, 1);
      expect(next.lastWorkoutDate, '2026-08-03');
      expect(next.weeklyWorkouts, 1);
      expect(next.weekStartDate, '2026-08-03');
    });

    test('extends the streak on a consecutive day', () {
      final next = advanceStreak(
        previous: const StreakState(
          currentStreak: 4,
          longestStreak: 9,
          lastWorkoutDate: '2026-08-03',
          weeklyWorkouts: 1,
          weekStartDate: '2026-08-03',
        ),
        completedAt: DateTime(2026, 8, 4, 7),
      );

      expect(next.currentStreak, 5);
      expect(next.longestStreak, 9, reason: 'still short of the record');
      expect(next.weeklyWorkouts, 2);
    });

    test('raises the record once the current streak passes it', () {
      final next = advanceStreak(
        previous: const StreakState(
          currentStreak: 9,
          longestStreak: 9,
          lastWorkoutDate: '2026-08-03',
        ),
        completedAt: DateTime(2026, 8, 4),
      );

      expect(next.currentStreak, 10);
      expect(next.longestStreak, 10);
    });

    test('resets to one after a missed day but keeps the record', () {
      final next = advanceStreak(
        previous: const StreakState(
          currentStreak: 12,
          longestStreak: 12,
          lastWorkoutDate: '2026-08-03',
        ),
        completedAt: DateTime(2026, 8, 6),
      );

      expect(next.currentStreak, 1);
      expect(next.longestStreak, 12);
    });

    test('a second workout the same day does not extend the streak', () {
      final next = advanceStreak(
        previous: const StreakState(
          currentStreak: 3,
          longestStreak: 5,
          lastWorkoutDate: '2026-08-04',
          weeklyWorkouts: 2,
          weekStartDate: '2026-08-03',
        ),
        completedAt: DateTime(2026, 8, 4, 21),
      );

      expect(next.currentStreak, 3, reason: 'a streak counts days, not sessions');
      expect(next.longestStreak, 5);
      expect(next.lastWorkoutDate, '2026-08-04');
    });

    test('a second workout the same day still counts toward the week', () {
      final next = advanceStreak(
        previous: const StreakState(
          currentStreak: 3,
          lastWorkoutDate: '2026-08-04',
          weeklyWorkouts: 2,
          weekStartDate: '2026-08-03',
        ),
        completedAt: DateTime(2026, 8, 4, 21),
      );

      expect(next.weeklyWorkouts, 3, reason: 'weekly counts sessions');
    });

    test('resets the weekly tally when the week rolls over', () {
      final next = advanceStreak(
        previous: const StreakState(
          currentStreak: 6,
          longestStreak: 6,
          lastWorkoutDate: '2026-08-09',
          weeklyWorkouts: 5,
          weekStartDate: '2026-08-03',
        ),
        completedAt: DateTime(2026, 8, 10),
      );

      expect(next.weeklyWorkouts, 1);
      expect(next.weekStartDate, '2026-08-10');
      expect(next.currentStreak, 7, reason: 'a new week does not break a streak');
    });

    test('treats an out-of-order backdated workout as a restart', () {
      // Negative gap: must not produce a negative or inflated streak.
      final next = advanceStreak(
        previous: const StreakState(
          currentStreak: 8,
          longestStreak: 8,
          lastWorkoutDate: '2026-08-10',
        ),
        completedAt: DateTime(2026, 8, 4),
      );

      expect(next.currentStreak, 1);
      expect(next.longestStreak, 8);
    });

    test('spans a month boundary as a consecutive day', () {
      final next = advanceStreak(
        previous: const StreakState(
          currentStreak: 2,
          longestStreak: 2,
          lastWorkoutDate: '2026-07-31',
        ),
        completedAt: DateTime(2026, 8, 1),
      );

      expect(next.currentStreak, 3);
    });

    test('spans a leap day as a consecutive day', () {
      final next = advanceStreak(
        previous: const StreakState(
          currentStreak: 1,
          longestStreak: 1,
          lastWorkoutDate: '2028-02-28',
        ),
        completedAt: DateTime(2028, 2, 29),
      );

      expect(next.currentStreak, 2);
    });

    test('builds a seven-day streak one day at a time', () {
      var state = const StreakState();
      for (var i = 0; i < 7; i++) {
        state = advanceStreak(
          previous: state,
          completedAt: DateTime(2026, 8, 3).add(Duration(days: i)),
        );
      }

      expect(state.currentStreak, 7);
      expect(state.longestStreak, 7);
      // Monday through Sunday is one week, so the tally never rolled over.
      expect(state.weeklyWorkouts, 7);
      expect(state.weekStartDate, '2026-08-03');
    });
  });

  group('streakStateFromUserData', () {
    test('returns a zeroed state for a null document', () {
      expect(streakStateFromUserData(null), const StreakState());
    });

    test('returns a zeroed state for a document with none of the fields', () {
      expect(streakStateFromUserData({'displayName': 'Ahmed'}), const StreakState());
    });

    test('reads a fully populated document', () {
      expect(
        streakStateFromUserData({
          'currentStreak': 4,
          'longestStreak': 11,
          'lastWorkoutDate': '2026-08-03',
          'weeklyWorkouts': 2,
          'weekStartDate': '2026-08-03',
        }),
        const StreakState(
          currentStreak: 4,
          longestStreak: 11,
          lastWorkoutDate: '2026-08-03',
          weeklyWorkouts: 2,
          weekStartDate: '2026-08-03',
        ),
      );
    });

    test('ignores wrongly typed and empty values instead of throwing', () {
      final state = streakStateFromUserData({
        'currentStreak': 'four',
        'longestStreak': double.nan,
        'lastWorkoutDate': '',
        'weeklyWorkouts': null,
        'weekStartDate': 42,
      });

      expect(state, const StreakState());
    });

    test('accepts a numeric counter stored as a double', () {
      expect(streakStateFromUserData({'currentStreak': 3.0}).currentStreak, 3);
    });
  });
}
