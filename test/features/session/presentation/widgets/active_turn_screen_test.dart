import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:zyntro_flutter/features/session/presentation/widgets/active_turn_screen.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/rep_counter_screen.dart';
import 'package:zyntro_flutter/core/models/models.dart';

void main() {
  Widget buildSubject({
    String exerciseName = 'Bench Press',
    int setNumber = 1,
    void Function({
      required int reps,
      required double weight,
      required int durationSeconds,
    })?
    onSetSubmit,
    VoidCallback? onTurnEnd,
    VoidCallback? onTimerStart,
  }) {
    return MaterialApp(
      home: ActiveTurnScreen(
        exerciseName: exerciseName,
        setNumber: setNumber,
        onSetSubmit:
            onSetSubmit ??
            ({required reps, required weight, required durationSeconds}) {},
        onTurnEnd: onTurnEnd,
        onTimerStart: onTimerStart,
      ),
    );
  }

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('shows exercise name and START button in READY phase', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(exerciseName: 'Squat', setNumber: 2));

    expect(find.text('Squat'), findsAny);
    expect(find.text('SET 2'), findsAny);
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('tapping START transitions to TIMING phase showing stopwatch', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('START'));
    await tester.pump();

    expect(find.text('0:00'), findsAny);
    expect(find.text('START'), findsNothing);
  });

  testWidgets('tapping START notifies that the set timer started', (
    tester,
  ) async {
    var starts = 0;
    await tester.pumpWidget(buildSubject(onTimerStart: () => starts += 1));

    await tester.tap(find.text('START'));
    await tester.pump();

    expect(starts, 1);
  });

  testWidgets('tapping screen in TIMING phase transitions to REPS phase', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('START'));
    await tester.pump();

    // Tap the hint text inside the TIMING GestureDetector
    await tester.tap(find.text('tap anywhere to stop'));
    await tester.pump();

    expect(find.byType(RepCounterScreen), findsOneWidget);
  });

  testWidgets('completing reps and submitting weight calls onSetSubmit', (
    tester,
  ) async {
    int? receivedReps;
    double? receivedWeight;

    await tester.pumpWidget(
      buildSubject(
        onSetSubmit:
            ({required reps, required weight, required durationSeconds}) {
              receivedReps = reps;
              receivedWeight = weight;
            },
      ),
    );

    // START → TIMING
    await tester.tap(find.text('START'));
    await tester.pump();

    // TIMING → REPS
    await tester.tap(find.text('tap anywhere to stop'));
    await tester.pump();

    expect(find.byType(RepCounterScreen), findsOneWidget);

    // Count 5 reps by tapping the count display
    await tester.tapAt(const Offset(200, 160));
    await tester.pump();
    for (int i = 1; i < 5; i++) {
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
    }

    // REPS → WEIGHT (tap the save button)
    await tester.tap(find.textContaining('Save'));
    await tester.pump();

    // Set weight to 80 using quick-pick (weight display starts at 0, so '80' is unique)
    await tester.tap(find.text('80'));
    await tester.pump();

    // Submit
    await tester.tap(find.text('Submit Set'));
    await tester.pump();

    expect(receivedReps, 5);
    expect(receivedWeight, 80.0);
  });

  testWidgets(
    'weight phase rep badge bounce does not throw during overshoot frames',
    (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.tap(find.text('tap anywhere to stop'));
      await tester.pump();
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
      await tester.tap(find.textContaining('Save'));
      await tester.pump(const Duration(milliseconds: 120));

      expect(tester.takeException(), isNull);
      expect(find.text('1 reps'), findsOneWidget);
    },
  );

  test(
    'weight phase rep badge bounce does not use an overshooting sequence curve',
    () {
      final source = File(
        'lib/features/session/presentation/widgets/active_turn_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('TweenSequence<double>')));
      expect(source, isNot(contains('curve: AppCurves.spring')));
    },
  );

  testWidgets('weight phase fits without bottom overflow on compact screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildSubject());
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('START'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('tap anywhere to stop'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(200, 160));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.textContaining('Save'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Submit Set'), findsOneWidget);
  });

  testWidgets('after submit resets to READY phase', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('START'));
    await tester.pump();

    // TIMING → REPS
    await tester.tap(find.text('tap anywhere to stop'));
    await tester.pump();

    expect(find.byType(RepCounterScreen), findsOneWidget);

    // Count 1 rep
    await tester.tapAt(const Offset(200, 300));
    await tester.pump();

    // REPS → WEIGHT
    await tester.tap(find.textContaining('Save'));
    await tester.pump();

    // Select a weight from quick-picks
    await tester.tap(find.text('40'));
    await tester.pump();

    // Submit
    await tester.tap(find.text('Submit Set'));
    await tester.pump();

    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('does not show Pass Turn when onTurnEnd provided', (
    tester,
  ) async {
    bool called = false;
    await tester.pumpWidget(buildSubject(onTurnEnd: () => called = true));

    expect(find.text('Pass Turn'), findsNothing);
    expect(called, isFalse);
  });

  testWidgets('two-person gym flow relies on automatic handoff control', (
    tester,
  ) async {
    bool handedOff = false;
    await tester.pumpWidget(
      buildSubject(
        exerciseName: 'Incline Press',
        setNumber: 3,
        onTurnEnd: () => handedOff = true,
      ),
    );

    expect(find.text('Incline Press'), findsAny);
    expect(find.text('SET 3'), findsAny);
    expect(find.text('Pass Turn'), findsNothing);
    expect(handedOff, isFalse);
  });

  testWidgets('bot gym turn shows fixed simulated values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActiveTurnScreen(
          exerciseName: 'Bench Press',
          setNumber: 1,
          botFriend: BotFriend.gymSimulation(),
          onSetSubmit:
              ({required reps, required weight, required durationSeconds}) {},
        ),
      ),
    );

    expect(find.text('7 sec'), findsOneWidget);
    expect(find.text('8 reps'), findsOneWidget);
    expect(find.text('80 kg'), findsOneWidget);
  });
}
