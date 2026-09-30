import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/features/session/presentation/widgets/parallel_cardio_view.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/parallel_gym_view.dart';

void main() {
  testWidgets('shows gym partner progress while cardio user shares time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ParallelCardioView(
          activityType: 'running',
          partner: const ParallelPartnerData(
            name: 'Host',
            workoutType: 'gym',
            currentExercise: 'Deadlift',
            totalSets: 5,
            totalVolume: 3200,
            elapsedTime: Duration(minutes: 8, seconds: 30),
          ),
          onCardioLog:
              ({
                required distanceKm,
                required durationSeconds,
                required activityType,
              }) {},
        ),
      ),
    );

    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Partner progress'), findsOneWidget);
    expect(find.text('Shared time'), findsOneWidget);
    expect(find.text('Deadlift'), findsOneWidget);
    expect(find.text('5 sets'), findsOneWidget);
    expect(find.text('3200 kg'), findsOneWidget);
  });
}
