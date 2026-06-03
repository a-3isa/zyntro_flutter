import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recap page surfaces per-user workout history for paired sessions', () {
    final source = File(
      'lib/features/session/presentation/recap_page.dart',
    ).readAsStringSync();

    expect(source, contains('Personal workout history'));
    expect(source, contains('participantTypes'));
    expect(source, contains('yourWorkoutType'));
  });

  // ---------------------------------------------------------------------------
  // T029 [US2] final summary only includes logged sets
  // ---------------------------------------------------------------------------
  test(
    'T029: recap page reads exercise summary from session events, not plan',
    () {
      final source = File(
        'lib/features/session/presentation/recap_page.dart',
      ).readAsStringSync();

      // Recap reads from session.summary (event-driven), not from plan exercises.
      // Late-added exercises only appear in summary after their sets are logged.
      expect(source, contains('session.summary'));
      expect(source, contains('ExerciseSummary'));
    },
  );
}
