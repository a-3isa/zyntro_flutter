import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/features/session/domain/gym_session_plan.dart';
import 'package:zyntro_flutter/features/session/domain/turn_plan_progress.dart';

void main() {
  GymSessionPlan planFor(String userId, {List<PlannedExercise>? exercises}) {
    return GymSessionPlan(
      userId: userId,
      source: GymSessionPlanSource.personal,
      isReady: true,
      exercises:
          exercises ??
          [
            PlannedExercise.custom(
              id: 'bench',
              name: 'Bench Press',
              plannedSets: 2,
              order: 0,
            ),
            PlannedExercise.custom(
              id: 'squat',
              name: 'Squat',
              plannedSets: 1,
              order: 1,
            ),
          ],
    );
  }

  group('TurnPlanProgress', () {
    test(
      'advances exercises only after their planned set count is reached',
      () {
        final plan = planFor('user-a');

        expect(
          TurnPlanProgress.participantState(
            plan,
            const {},
          ).currentExercise?.name,
          'Bench Press',
        );
        expect(
          TurnPlanProgress.participantState(plan, const {
            'bench': 1,
          }).currentSetNumber,
          2,
        );
        expect(
          TurnPlanProgress.participantState(plan, const {
            'bench': 2,
          }).currentExercise?.name,
          'Squat',
        );

        final complete = TurnPlanProgress.participantState(plan, const {
          'bench': 2,
          'squat': 1,
        });
        expect(complete.isComplete, isTrue);
        expect(complete.currentExercise, isNull);
      },
    );

    test('alternates to the next participant with remaining planned work', () {
      final plans = {'user-a': planFor('user-a'), 'user-b': planFor('user-b')};

      final next = TurnPlanProgress.nextActiveParticipant(
        currentUserId: 'user-a',
        participants: const ['user-a', 'user-b'],
        plans: plans,
        completedSetsByUserAndExercise: const {
          'user-a': {'bench': 1},
        },
      );

      expect(next, 'user-b');
    });

    test('returns null when every participant has finished planned work', () {
      final plans = {'user-a': planFor('user-a'), 'user-b': planFor('user-b')};

      final next = TurnPlanProgress.nextActiveParticipant(
        currentUserId: 'user-b',
        participants: const ['user-a', 'user-b'],
        plans: plans,
        completedSetsByUserAndExercise: const {
          'user-a': {'bench': 2, 'squat': 1},
          'user-b': {'bench': 2, 'squat': 1},
        },
      );

      expect(next, isNull);
      expect(
        TurnPlanProgress.isSessionComplete(
          plans: plans,
          completedSetsByUserAndExercise: const {
            'user-a': {'bench': 2, 'squat': 1},
            'user-b': {'bench': 2, 'squat': 1},
          },
        ),
        isTrue,
      );
    });

    test('uses appended exercises as the next planned work', () {
      final plan = planFor(
        'user-a',
        exercises: [
          PlannedExercise.custom(
            id: 'bench',
            name: 'Bench Press',
            plannedSets: 1,
            order: 0,
          ),
          PlannedExercise.custom(
            id: 'curl',
            name: 'Curl',
            plannedSets: 2,
            order: 1,
          ),
        ],
      );

      final state = TurnPlanProgress.participantState(plan, const {'bench': 1});

      expect(state.currentExercise?.name, 'Curl');
      expect(state.currentSetNumber, 1);
      expect(state.isComplete, isFalse);
    });
  });
}
