import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/features/session/presentation/cardio_activity_options.dart';

void main() {
  group('cardioActivityOptions', () {
    test('offers running and jogging for a run', () {
      final values = cardioActivityOptions(WorkoutType.running)
          .map((o) => o['value'])
          .toList();

      expect(values, containsAll(<String>['running', 'jogging']));
    });

    test('offers the cycling variants for a ride', () {
      final values = cardioActivityOptions(WorkoutType.cycling)
          .map((o) => o['value'])
          .toList();

      expect(values, contains('cycling'));
    });

    test('offers the swimming variants for a swim', () {
      final values = cardioActivityOptions(WorkoutType.swimming)
          .map((o) => o['value'])
          .toList();

      expect(values, contains('swimming'));
    });

    test('offers walking for a walk', () {
      final values = cardioActivityOptions(WorkoutType.walking)
          .map((o) => o['value'])
          .toList();

      expect(values, contains('walking'));
    });

    test('every option carries a value, label and icon', () {
      for (final type in WorkoutType.values) {
        for (final option in cardioActivityOptions(type)) {
          expect(option['value'], isA<String>(), reason: type.value);
          expect(option['label'], isA<String>(), reason: type.value);
          expect(option['icon'], isA<IconData>(), reason: type.value);
        }
      }
    });

    test('never throws for a non-cardio workout type', () {
      // The picker is only shown for cardio, but the switch must still be total
      // — a missing case would throw at build time on the session screen.
      for (final type in WorkoutType.values) {
        expect(() => cardioActivityOptions(type), returnsNormally,
            reason: type.value);
      }
    });
  });

  group('cardioActivityIcon', () {
    test('maps each run-like activity to the running glyph', () {
      expect(cardioActivityIcon('running'), Icons.directions_run);
      expect(cardioActivityIcon('jogging'), Icons.directions_run);
    });

    test('maps each ride-like activity to the bike glyph', () {
      expect(cardioActivityIcon('cycling'), Icons.directions_bike);
      expect(cardioActivityIcon('stationary'), Icons.directions_bike);
    });

    test('maps each swim-like activity to the pool glyph', () {
      expect(cardioActivityIcon('swimming'), Icons.pool);
      expect(cardioActivityIcon('laps'), Icons.pool);
    });

    test('maps each walk-like activity to the walking glyph', () {
      expect(cardioActivityIcon('walking'), Icons.directions_walk);
      expect(cardioActivityIcon('hiking'), Icons.directions_walk);
    });

    test('falls back rather than throwing on an unknown activity', () {
      expect(cardioActivityIcon('kitesurfing'), Icons.fitness_center);
      expect(cardioActivityIcon(''), Icons.fitness_center);
    });

    test('every option the picker offers has a real icon mapping', () {
      // A value the picker can select but the icon switch does not know would
      // silently render a dumbbell next to a run.
      for (final type in WorkoutType.values) {
        for (final option in cardioActivityOptions(type)) {
          final value = option['value'] as String;
          expect(
            cardioActivityIcon(value),
            isNot(Icons.fitness_center),
            reason: '$value falls through to the default icon',
          );
        }
      }
    });
  });

  group('cardioActivityLabel', () {
    test('capitalises the activity', () {
      expect(cardioActivityLabel('running'), 'Running');
      expect(cardioActivityLabel('swimming'), 'Swimming');
    });

    test('falls back when no activity is set', () {
      expect(cardioActivityLabel(null), 'Activity');
    });

    test('leaves an already-capitalised value alone', () {
      expect(cardioActivityLabel('Running'), 'Running');
    });

    test('handles a single character without throwing', () {
      expect(cardioActivityLabel('r'), 'R');
    });
  });
}
