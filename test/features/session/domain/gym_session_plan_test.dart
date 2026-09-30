import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/features/session/domain/gym_session_plan.dart';

void main() {
  group('GymSessionPlan', () {
    test('serializes participant-owned type-specific plan fields', () {
      final plan = GymSessionPlan(
        userId: 'user-1',
        workoutType: WorkoutType.running,
        source: GymSessionPlanSource.personalCopy,
        isReady: true,
        exercises: const [],
        stages: const [
          PlannedWorkoutStage(
            id: 'stage-1',
            label: 'Warmup',
            targetKind: PlanTargetKind.duration,
            targetValue: 300,
          ),
        ],
        targets: const {'distanceKm': 1.5},
        updatedAt: DateTime(2026, 1, 1),
      );

      final map = plan.toMap();
      final parsed = GymSessionPlan.fromMap(map);

      expect(map['workoutType'], 'running');
      expect(map['source'], 'personal_copy');
      expect(parsed.workoutType, WorkoutType.running);
      expect(parsed.source, GymSessionPlanSource.personalCopy);
      expect(parsed.stages.single.targetKind, PlanTargetKind.duration);
      expect(parsed.targets['distanceKm'], 1.5);
      expect(parsed.updatedAt, DateTime(2026, 1, 1));
    });

    // -------------------------------------------------------------------------
    // T008: catalog/custom identity fields and 1-20 set validation
    // -------------------------------------------------------------------------

    group('PlannedExercise catalog identity', () {
      test('catalog factory preserves exerciseId and source', () {
        final ex = PlannedExercise.catalog(
          id: 'pe-1',
          exerciseId: 'cat-bench',
          name: 'Bench Press',
          plannedSets: 4,
          order: 0,
          muscleGroup: 'chest',
        );
        expect(ex.source, PlannedExerciseSource.catalog);
        expect(ex.exerciseId, 'cat-bench');
        expect(ex.personalExerciseId, isNull);
      });

      test('custom factory preserves personalExerciseId and source', () {
        final ex = PlannedExercise.custom(
          id: 'pe-2',
          name: 'Mystery Move',
          plannedSets: 3,
          order: 1,
          personalExerciseId: 'pers-abc',
        );
        expect(ex.source, PlannedExerciseSource.custom);
        expect(ex.personalExerciseId, 'pers-abc');
        expect(ex.exerciseId, isNull);
      });

      test('fromMap round-trips catalog identity', () {
        final original = PlannedExercise.catalog(
          id: 'pe-3',
          exerciseId: 'cat-squat',
          name: 'Squat',
          plannedSets: 5,
          order: 0,
        );
        final parsed = PlannedExercise.fromMap(original.toMap());
        expect(parsed.source, PlannedExerciseSource.catalog);
        expect(parsed.exerciseId, 'cat-squat');
        expect(parsed.plannedSets, 5);
      });

      test('fromMap round-trips custom identity with personalExerciseId', () {
        final original = PlannedExercise.custom(
          id: 'pe-4',
          name: 'Custom Lift',
          plannedSets: 2,
          order: 0,
          personalExerciseId: 'pers-xyz',
        );
        final parsed = PlannedExercise.fromMap(original.toMap());
        expect(parsed.source, PlannedExerciseSource.custom);
        expect(parsed.personalExerciseId, 'pers-xyz');
      });

      test('toMap includes personalExerciseId when set', () {
        final ex = PlannedExercise.custom(
          id: 'pe-5',
          name: 'Custom Lift',
          plannedSets: 3,
          order: 0,
          personalExerciseId: 'pers-xyz',
        );
        expect(ex.toMap()['personalExerciseId'], 'pers-xyz');
      });

      test('copyWithPlanFields preserves catalog identity', () {
        final original = PlannedExercise.catalog(
          id: 'pe-6',
          exerciseId: 'cat-row',
          name: 'Row',
          plannedSets: 3,
          order: 0,
          muscleGroup: 'back',
          equipment: 'Cable',
        );

        final copied = original.copyWithPlanFields(
          id: 'pe-7',
          plannedSets: 5,
          order: 2,
        );

        expect(copied.source, PlannedExerciseSource.catalog);
        expect(copied.id, 'pe-7');
        expect(copied.exerciseId, 'cat-row');
        expect(copied.personalExerciseId, isNull);
        expect(copied.plannedSets, 5);
        expect(copied.order, 2);
        expect(copied.muscleGroup, 'back');
        expect(copied.equipment, 'Cable');
      });

      test('copyWithPlanFields preserves custom identity', () {
        final original = PlannedExercise.custom(
          id: 'pe-8',
          name: 'Custom Lift',
          plannedSets: 2,
          order: 0,
          personalExerciseId: 'pers-row',
          muscleGroup: 'back',
          equipment: 'Cable',
        );

        final copied = original.copyWithPlanFields(plannedSets: 4, order: 3);

        expect(copied.source, PlannedExerciseSource.custom);
        expect(copied.id, 'pe-8');
        expect(copied.exerciseId, isNull);
        expect(copied.personalExerciseId, 'pers-row');
        expect(copied.plannedSets, 4);
        expect(copied.order, 3);
        expect(copied.muscleGroup, 'back');
        expect(copied.equipment, 'Cable');
      });
    });

    group('PlannedExercise set count validation (1-20)', () {
      test('allows plannedSets = 1', () {
        expect(
          () => PlannedExercise.custom(
              id: 'x', name: 'A', plannedSets: 1, order: 0),
          returnsNormally,
        );
      });

      test('allows plannedSets = 20', () {
        expect(
          () => PlannedExercise.custom(
              id: 'x', name: 'A', plannedSets: 20, order: 0),
          returnsNormally,
        );
      });

      test('rejects plannedSets = 0', () {
        expect(
          () => PlannedExercise.custom(
              id: 'x', name: 'A', plannedSets: 0, order: 0),
          throwsArgumentError,
        );
      });

      test('rejects plannedSets = 21', () {
        expect(
          () => PlannedExercise.custom(
              id: 'x', name: 'A', plannedSets: 21, order: 0),
          throwsArgumentError,
        );
      });

      test('fromMap with plannedSets = 21 throws via factory', () {
        final data = {
          'id': 'pe-bad',
          'sourceType': 'custom',
          'name': 'Bad',
          'plannedSets': 21,
          'order': 0,
        };
        expect(() => PlannedExercise.fromMap(data), throwsArgumentError);
      });
    });

    test(
      'creates default personal plans for supported non-gym workout types',
      () {
        final running = GymSessionPlan.defaultPersonalPlan(
          userId: 'runner-1',
          workoutType: WorkoutType.running,
        );
        final yoga = GymSessionPlan.defaultPersonalPlan(
          userId: 'yogi-1',
          workoutType: WorkoutType.yoga,
        );
        final hiit = GymSessionPlan.defaultPersonalPlan(
          userId: 'hiit-1',
          workoutType: WorkoutType.hiit,
        );

        expect(running.workoutType, WorkoutType.running);
        expect(running.source, GymSessionPlanSource.personal);
        expect(running.isReady, isTrue);
        expect(running.stages.single.targetKind, PlanTargetKind.distance);
        expect(running.targets['distanceKm'], greaterThan(0));

        expect(yoga.stages.first.targetKind, PlanTargetKind.stageCompletion);
        expect(yoga.targets['durationSeconds'], greaterThan(0));

        expect(hiit.stages.first.targetKind, PlanTargetKind.rounds);
        expect(hiit.targets['rounds'], greaterThan(0));
      },
    );
  });
}
