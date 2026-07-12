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

/// Pushes [GymExercisePickerSheet] as a real modal route (matching production
/// usage) so `Navigator.pop` on Save can be captured via [onResult].
Widget _harness(ValueSetter<List<PlannedExercise>?> onResult) {
  return ProviderScope(
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await showModalBottomSheet<List<PlannedExercise>>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const GymExercisePickerSheet(),
                );
                onResult(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('filters the exercise catalog as the user searches', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const GymExercisePickerSheet()));

    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Lat Pulldown'), findsNothing);
  });

  testWidgets('selecting and saving one exercise returns it', (tester) async {
    List<PlannedExercise>? captured;

    await tester.pumpWidget(_harness((r) => captured = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    // Row is now selected — inline sets stepper appears, Save button enables.
    expect(find.text('3 sets'), findsOneWidget);
    await tester.tap(find.text('Save 1 exercise'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured, hasLength(1));
    expect(captured!.first.name, 'Bench Press');
    expect(captured!.first.source, PlannedExerciseSource.catalog);
    expect(captured!.first.plannedSets, 3);
  });

  testWidgets('tapping a selected exercise again deselects it', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const GymExercisePickerSheet()));

    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    expect(find.text('3 sets'), findsOneWidget);
    expect(find.text('Save 1 exercise'), findsOneWidget);

    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    expect(find.text('3 sets'), findsNothing);
    expect(find.text('Select exercises to continue'), findsOneWidget);
  });

  testWidgets('the inline stepper adjusts the selected set count', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const GymExercisePickerSheet()));

    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('3 sets'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('4 sets'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pumpAndSettle();
    expect(find.text('2 sets'), findsOneWidget);
  });

  testWidgets(
    'selecting two exercises and saving returns both in tap order with their set counts',
    (tester) async {
      List<PlannedExercise>? captured;

      await tester.pumpWidget(_harness((r) => captured = r));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'bench');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded)); // Bench Press -> 4 sets
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'deadlift');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deadlift'));
      await tester.pumpAndSettle();

      expect(find.text('Save 2 exercises'), findsOneWidget);
      await tester.tap(find.text('Save 2 exercises'));
      await tester.pumpAndSettle();

      expect(captured, hasLength(2));
      expect(captured![0].name, 'Bench Press');
      expect(captured![0].plannedSets, 4);
      expect(captured![0].order, 0);
      expect(captured![1].name, 'Deadlift');
      expect(captured![1].plannedSets, 3);
      expect(captured![1].order, 1);
    },
  );

  testWidgets('lets the user create a custom exercise when search has no match', (
    tester,
  ) async {
    List<PlannedExercise>? captured;

    await tester.pumpWidget(_harness((r) => captured = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

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

    // Custom exercise is auto-selected on creation.
    expect(find.text('3 sets'), findsOneWidget);
    await tester.tap(find.text('Save 1 exercise'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured, hasLength(1));
    expect(captured!.first.name, 'Mystery Move');
    expect(captured!.first.source, PlannedExerciseSource.custom);
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
      'placeholder: set count < 1 is rejected before confirm (FR-005a)',
      (tester) async {
    // TODO(T023): attempt count=0, verify the stepper's decrement is disabled
  });

  testWidgets(
      'placeholder: set count > 20 is rejected before confirm (FR-005a)',
      (tester) async {
    // TODO(T023): attempt count=21, verify the stepper's increment is disabled
  });

  // ---------------------------------------------------------------------------
  // Placeholder: US3 consistent search (T036, T039)
  // ---------------------------------------------------------------------------

  testWidgets(
      'T036: same search term returns consistent details across picker consumers',
      (tester) async {
    // Two picker instances (simulating start-session and late-session consumers)
    // with the same query should show the same exercise names.

    // Instance 1 — start-session consumer
    await tester.pumpWidget(_wrap(const GymExercisePickerSheet()));
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
    await tester.pumpWidget(_wrap(const GymExercisePickerSheet()));
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
  });

  testWidgets(
      'T039: empty state shows explicit custom creation action (FR-010)',
      (tester) async {
    await tester.pumpWidget(_wrap(const GymExercisePickerSheet()));

    await tester.enterText(find.byType(TextField), 'zzzzznotanexercise');
    await tester.pumpAndSettle();

    expect(find.text('No exercises matched'), findsOneWidget);
    expect(find.text('Add custom exercise'), findsOneWidget);
  });
}
