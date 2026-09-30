import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/features/session/presentation/widgets/parallel_gym_view.dart';

void main() {
  testWidgets('shows partner progress with type label and shared time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 720,
          child: ParallelGymView(
            exerciseName: 'Bench Press',
            setNumber: 1,
            partner: const ParallelPartnerData(
              name: 'Mina',
              workoutType: 'running',
              totalDistance: 1.25,
              averagePace: '5:30/km',
              elapsedTime: Duration(minutes: 12, seconds: 4),
            ),
            onSetSubmit:
                ({required reps, required weight, required durationSeconds}) {},
          ),
        ),
      ),
    );

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Mina'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Partner progress'), findsOneWidget);
    expect(find.text('Shared time'), findsOneWidget);
    expect(find.text('1.25 km'), findsOneWidget);
    expect(find.text('12:04'), findsOneWidget);
  });
}
