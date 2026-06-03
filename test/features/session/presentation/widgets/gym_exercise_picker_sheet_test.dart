import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/features/session/domain/gym_session_plan.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/gym_exercise_picker_sheet.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 500, height: 700, child: child),
        ),
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

    // Set-count selector appears; confirm with default count
    expect(find.text('Confirm'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
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

    // Set-count selector appears; confirm with default count
    expect(find.text('Confirm'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.name, 'Mystery Move');
    expect(selected!.source, PlannedExerciseSource.custom);
  });

  // ---------------------------------------------------------------------------
  // Placeholder: database-backed search (T017, T022)
  // ---------------------------------------------------------------------------

  testWidgets(
      'placeholder: database-backed search returns ExerciseCatalogService results',
      (tester) async {
    // TODO(T017): wire ExerciseCatalogService, stub results, verify displayed
    // Search 'bench' should show shared catalog results from service, not only local data
  });

  testWidgets(
      'placeholder: search results show exercise name and distinguishing detail (FR-004)',
      (tester) async {
    // TODO(T022): each result tile shows name + muscle group/category/equipment
  });

  // ---------------------------------------------------------------------------
  // Placeholder: 1-20 set selection (T017, T023)
  // ---------------------------------------------------------------------------

  testWidgets(
      'placeholder: selecting exercise shows set-count selector before confirm',
      (tester) async {
    // TODO(T017): tap an exercise result, verify set selector appears
  });

  testWidgets(
      'placeholder: picker returns selected exercise with non-default set count',
      (tester) async {
    // TODO(T017): choose set count != 3, confirm, verify returned plannedSets matches
  });

  testWidgets(
      'placeholder: set count < 1 is rejected before confirm (FR-005a)',
      (tester) async {
    // TODO(T023): attempt count=0, verify confirmation is blocked
  });

  testWidgets(
      'placeholder: set count > 20 is rejected before confirm (FR-005a)',
      (tester) async {
    // TODO(T023): attempt count=21, verify confirmation is blocked
  });

  // ---------------------------------------------------------------------------
  // Placeholder: US3 consistent search (T036, T039)
  // ---------------------------------------------------------------------------

  testWidgets(
      'T036: same search term returns consistent details across picker consumers',
      (tester) async {
    // Two picker instances (simulating start-session and late-session consumers)
    // with the same query should show the same exercise names.
    PlannedExercise? selected1;
    PlannedExercise? selected2;

    // Instance 1 — start-session consumer
    await tester.pumpWidget(
      _wrap(GymExercisePickerSheet(onExerciseSelected: (e) => selected1 = e)),
    );
    await tester.enterText(find.byType(TextField), 'squat');
    await tester.pumpAndSettle();
    final names1 = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Text),
        ))
        .where((t) => t.data != null && t.data!.isNotEmpty)
        .map((t) => t.data!)
        .toList();

    // Instance 2 — late-session consumer (same widget, different instance)
    await tester.pumpWidget(
      _wrap(GymExercisePickerSheet(onExerciseSelected: (e) => selected2 = e)),
    );
    await tester.enterText(find.byType(TextField), 'squat');
    await tester.pumpAndSettle();
    final names2 = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Text),
        ))
        .where((t) => t.data != null && t.data!.isNotEmpty)
        .map((t) => t.data!)
        .toList();

    expect(names1, equals(names2));
    // Suppress unused variable warnings
    expect(selected1, isNull);
    expect(selected2, isNull);
  });

  testWidgets(
      'T039: empty state shows explicit custom creation action (FR-010)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(GymExercisePickerSheet(onExerciseSelected: (_) {})),
    );

    await tester.enterText(find.byType(TextField), 'zzzzznotanexercise');
    await tester.pumpAndSettle();

    expect(find.text('No exercises matched'), findsOneWidget);
    expect(find.text('Add custom exercise'), findsOneWidget);
  });
}
