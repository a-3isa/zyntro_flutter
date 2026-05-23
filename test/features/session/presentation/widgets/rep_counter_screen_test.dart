import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/features/session/presentation/widgets/rep_counter_screen.dart';

void main() {
  Widget buildSubject({required void Function(int) onDone, int initial = 0}) {
    return MaterialApp(
      home: RepCounterScreen(initialCount: initial, onDone: onDone),
    );
  }

  testWidgets('starts at the initial count', (tester) async {
    await tester.pumpWidget(buildSubject(onDone: (_) {}));
    expect(find.text('0'), findsOneWidget);
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

  testWidgets('Done button calls onDone with the current count', (tester) async {
    int? received;
    await tester.pumpWidget(buildSubject(onDone: (reps) => received = reps));

    // Tap body three times
    for (int i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
    }

    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(received, 3);
  });

  testWidgets('Done button is disabled when count is 0', (tester) async {
    bool called = false;
    await tester.pumpWidget(buildSubject(onDone: (_) => called = true));

    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(called, isFalse);
  });

  testWidgets('reset button returns count to 0', (tester) async {
    await tester.pumpWidget(buildSubject(onDone: (_) {}));

    await tester.tapAt(const Offset(200, 300));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // Reset button is a tooltip or icon — find by icon
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();

    expect(find.text('0'), findsOneWidget);
  });
}
