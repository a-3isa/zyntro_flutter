import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/features/session/presentation/widgets/rep_counter_screen.dart';

void main() {
  Widget buildSubject({required void Function(int) onDone, int initial = 0}) {
    return MaterialApp(
      home: RepCounterScreen(initialCount: initial, onDone: onDone),
    );
  }

  testWidgets('shows TAP prompt when count is 0', (tester) async {
    await tester.pumpWidget(buildSubject(onDone: (_) {}));
    expect(find.text('TAP'), findsOneWidget);
  });

  testWidgets('shows initial count when non-zero', (tester) async {
    await tester.pumpWidget(buildSubject(onDone: (_) {}, initial: 5));
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('tapping the screen body increments the count', (tester) async {
    await tester.pumpWidget(buildSubject(onDone: (_) {}));

    // Tap center of screen (body GestureDetector area)
    await tester.tapAt(const Offset(200, 300));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);

    await tester.tapAt(const Offset(200, 300));
    await tester.pump();

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('Save button calls onDone with the current count', (tester) async {
    int? received;
    await tester.pumpWidget(buildSubject(onDone: (reps) => received = reps));

    // Tap body three times
    for (int i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
    }

    await tester.tap(find.textContaining('Save'));
    await tester.pump();

    expect(received, 3);
  });

  testWidgets('Save button is disabled when count is 0', (tester) async {
    bool called = false;
    await tester.pumpWidget(buildSubject(onDone: (_) => called = true));

    // Save reps button is shown but disabled
    expect(find.textContaining('Save'), findsOneWidget);
    await tester.tap(find.textContaining('Save'));
    await tester.pump();

    expect(called, isFalse);
  });

  testWidgets('undo button decrements count', (tester) async {
    await tester.pumpWidget(buildSubject(onDone: (_) {}));

    await tester.tapAt(const Offset(200, 300));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.undo_rounded));
    await tester.pump();

    expect(find.text('TAP'), findsOneWidget);
  });
}
