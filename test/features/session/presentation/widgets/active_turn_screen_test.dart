import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:zyntro_flutter/features/session/presentation/widgets/active_turn_screen.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/rep_counter_screen.dart';

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

  testWidgets('shows exercise name and START button in READY phase', (tester) async {
    await tester.pumpWidget(buildSubject(exerciseName: 'Squat', setNumber: 2));

    expect(find.text('Squat'), findsAny);
    expect(find.text('SET 2'), findsAny);
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('tapping START transitions to TIMING phase showing stopwatch', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('START'));
    await tester.pump();

    expect(find.text('0:00'), findsAny);
    expect(find.text('START'), findsNothing);
  });

  testWidgets('tapping screen in TIMING phase transitions to REPS phase', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('START'));
    await tester.pump();

    // Tap the hint text inside the TIMING GestureDetector
    await tester.tap(find.text('tap anywhere to stop'));
    await tester.pump();

    expect(find.byType(RepCounterScreen), findsOneWidget);
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
    await tester.tap(find.text('tap anywhere to stop'));
    await tester.pump();

    expect(find.byType(RepCounterScreen), findsOneWidget);

    // Count 5 reps by tapping the count display
    await tester.tap(find.text('TAP'));  // 0 → 1
    await tester.pump();
    for (int i = 1; i < 5; i++) {
      await tester.tap(find.text('$i'));  // N → N+1
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

  testWidgets('after submit resets to READY phase', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('START'));
    await tester.pump();

    // TIMING → REPS
    await tester.tap(find.text('tap anywhere to stop'));
    await tester.pump();

    expect(find.byType(RepCounterScreen), findsOneWidget);

    // Count 1 rep
    await tester.tap(find.text('TAP'));
    await tester.pump();

    // REPS → WEIGHT
    await tester.tap(find.textContaining('Save'));
    await tester.pump();

    // Submit with default weight
    await tester.tap(find.text('Submit Set'));
    await tester.pump();

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
