import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/data/gym_exercises.dart';
import 'package:zyntro_flutter/features/session/domain/gym_session_plan.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/gym_live_session_panel.dart';

void main() {
  testWidgets('live panel shows current set progress and finish action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GymLiveSessionPanel(
            exercise: PlannedExercise.catalog(
              id: 'bench_0',
              exerciseId: 'bench_press',
              name: 'Bench Press',
              muscleGroup: MuscleGroup.chest.displayName,
              equipment: Equipment.barbell.displayName,
              plannedSets: 4,
              order: 0,
            ),
            currentSetNumber: 2,
            completedSets: 1,
            isUsersTurn: true,
            isSetRunning: true,
            onStartSet: () {},
            onFinishSet: () {},
          ),
        ),
      ),
    );

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Set 2 of 4'), findsOneWidget);
    expect(find.text('Finish Set'), findsOneWidget);
    expect(find.text('1 completed'), findsOneWidget);
  });

  testWidgets('live panel shows waiting state during partner turn', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GymLiveSessionPanel(
            exercise: PlannedExercise.catalog(
              id: 'bench_0',
              exerciseId: 'bench_press',
              name: 'Bench Press',
              muscleGroup: MuscleGroup.chest.displayName,
              equipment: Equipment.barbell.displayName,
              plannedSets: 4,
              order: 0,
            ),
            currentSetNumber: 2,
            completedSets: 1,
            isUsersTurn: false,
            isSetRunning: false,
            onStartSet: () {},
            onFinishSet: () {},
          ),
        ),
      ),
    );

    expect(find.text('Partner turn'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Cheer them on while they finish this set.'), findsOneWidget);
  });
}
