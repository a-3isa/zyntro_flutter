import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/features/session/domain/gym_session_plan.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/gym_exercise_picker_sheet.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 500, height: 700, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('filters the exercise catalog as the user searches', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        GymExercisePickerSheet(
          onExerciseSelected: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Lat Pulldown'), findsNothing);
  });

  testWidgets('returns a catalog exercise when one is tapped', (tester) async {
    PlannedExercise? selected;

    await tester.pumpWidget(
      _wrap(
        GymExercisePickerSheet(
          onExerciseSelected: (exercise) {
            selected = exercise;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.name, 'Bench Press');
    expect(selected!.source, PlannedExerciseSource.catalog);
  });

  testWidgets('lets the user create a custom exercise when search has no match', (
    tester,
  ) async {
    PlannedExercise? selected;

    await tester.pumpWidget(
      _wrap(
        GymExercisePickerSheet(
          onExerciseSelected: (exercise) {
            selected = exercise;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'mystery move');
    await tester.pumpAndSettle();

    expect(find.text('No exercises matched'), findsOneWidget);

    await tester.tap(find.text('Add custom exercise'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Exercise name'),
      'Mystery Move',
    );
    await tester.tap(find.text('Save custom exercise'));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.name, 'Mystery Move');
    expect(selected!.source, PlannedExerciseSource.custom);
  });
}
