import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/features/session/presentation/widgets/active_turn_screen.dart';

void main() {
  Widget buildSubject({
    String exerciseName = 'Bench Press',
    int setNumber = 1,
    void Function({required int reps, required double weight, required int durationSeconds})? onSetSubmit,
    VoidCallback? onTurnEnd,
  }) {
    return MaterialApp(
      home: ActiveTurnScreen(
        exerciseName: exerciseName,
        setNumber: setNumber,
        onSetSubmit: onSetSubmit ?? ({required reps, required weight, required durationSeconds}) {},
        onTurnEnd: onTurnEnd,
      ),
    );
  }

  testWidgets('shows exercise name and START button in READY phase', (tester) async {
    await tester.pumpWidget(buildSubject(exerciseName: 'Squat', setNumber: 2));

    expect(find.text('Squat'), findsAny);
    expect(find.text('Set 2'), findsAny);
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('tapping START transitions to TIMING phase showing stopwatch', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('START'));
    await tester.pump();

    // Stopwatch should show 0:00
    expect(find.text('0:00'), findsAny);
    expect(find.text('START'), findsNothing);
  });

  testWidgets('tapping screen in TIMING phase transitions to REPS phase', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('START'));
    await tester.pump();

    // Tap body to stop the timer
    await tester.tapAt(const Offset(200, 300));
    await tester.pump();

    // Should now show RepCounterScreen (shows '0' count)
    expect(find.text('0'), findsAny);
    expect(find.text('Done'), findsAny);
  });

  testWidgets('completing reps and submitting weight calls onSetSubmit', (tester) async {
    int? receivedReps;
    double? receivedWeight;

    await tester.pumpWidget(buildSubject(
      onSetSubmit: ({required reps, required weight, required durationSeconds}) {
        receivedReps = reps;
        receivedWeight = weight;
      },
    ));

    // START → TIMING
    await tester.tap(find.text('START'));
    await tester.pump();

    // TIMING → REPS
    await tester.tapAt(const Offset(200, 300));
    await tester.pump();

    // Tap 5 reps
    for (int i = 0; i < 5; i++) {
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
    }

    // Done → WEIGHT
    await tester.tap(find.text('Done'));
    await tester.pump();

    // Enter weight
    await tester.enterText(find.byType(TextFormField), '80');
    await tester.tap(find.text('Submit Set'));
    await tester.pump();

    expect(receivedReps, 5);
    expect(receivedWeight, 80.0);
  });

  testWidgets('after submit resets to READY phase', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('START'));
    await tester.pump();

    await tester.tapAt(const Offset(200, 300));
    await tester.pump();

    await tester.tapAt(const Offset(200, 300));
    await tester.pump();

    await tester.tap(find.text('Done'));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), '60');
    await tester.tap(find.text('Submit Set'));
    await tester.pump();

    // Back to READY
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('shows Pass Turn button when onTurnEnd provided', (tester) async {
    bool called = false;
    await tester.pumpWidget(buildSubject(onTurnEnd: () => called = true));

    expect(find.text('Pass Turn'), findsAny);
    await tester.tap(find.text('Pass Turn'));
    await tester.pump();

    expect(called, isTrue);
  });
}
