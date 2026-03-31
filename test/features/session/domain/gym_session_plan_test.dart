import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/session/domain/gym_session_plan.dart';

// ignore: subtype_of_sealed_class
class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  group('GymSessionPlan', () {
    test('round-trips a catalog exercise and a custom exercise', () {
      final plan = GymSessionPlan(
        userId: 'user-1',
        source: GymSessionPlanSource.hostTemplate,
        isReady: true,
        exercises: [
          PlannedExercise.catalog(
            id: 'plan-ex-1',
            exerciseId: 'catalog-123',
            name: 'Bench Press',
            plannedSets: 4,
            order: 0,
            muscleGroup: 'chest',
            equipment: 'barbell',
          ),
          PlannedExercise.custom(
            id: 'plan-ex-2',
            name: 'Landmine Press',
            plannedSets: 3,
            order: 1,
            muscleGroup: 'shoulders',
            equipment: 'landmine',
          ),
        ],
      );

      final serialized = plan.toMap();
      final deserialized = GymSessionPlan.fromMap(serialized);

      expect(deserialized.userId, 'user-1');
      expect(deserialized.source, GymSessionPlanSource.hostTemplate);
      expect(deserialized.isReady, isTrue);
      expect(deserialized.exercises.length, 2);
      expect(deserialized.exercises[0].id, 'plan-ex-1');
      expect(deserialized.exercises[0].source, PlannedExerciseSource.catalog);
      expect(deserialized.exercises[0].exerciseId, 'catalog-123');
      expect(deserialized.exercises[0].name, 'Bench Press');
      expect(deserialized.exercises[0].plannedSets, 4);
      expect(deserialized.exercises[0].order, 0);
      expect(deserialized.exercises[0].muscleGroup, 'chest');
      expect(deserialized.exercises[0].equipment, 'barbell');
      expect(deserialized.exercises[1].id, 'plan-ex-2');
      expect(deserialized.exercises[1].source, PlannedExerciseSource.custom);
      expect(deserialized.exercises[1].exerciseId, isNull);
      expect(deserialized.exercises[1].name, 'Landmine Press');
      expect(deserialized.exercises[1].plannedSets, 3);
      expect(deserialized.exercises[1].order, 1);
      expect(deserialized.exercises[1].muscleGroup, 'shoulders');
      expect(deserialized.exercises[1].equipment, 'landmine');
    });

    test('rejects invalid catalog/custom exercise construction', () {
      expect(
        () => PlannedExercise.catalog(
          id: 'bad-1',
          exerciseId: '',
          name: 'Bench Press',
          plannedSets: 3,
          order: 0,
        ),
        throwsArgumentError,
      );

      expect(
        () => PlannedExercise.custom(
          id: 'bad-2',
          name: '',
          plannedSets: 3,
          order: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Session.fromFirestore', () {
    test(
      'legacy documents default to SessionPhase.live when phase is missing',
      () {
        final doc = MockDocumentSnapshot();
        when(() => doc.id).thenReturn('session-1');
        when(() => doc.data()).thenReturn({
          'type': 'gym',
          'title': 'Morning Session',
          'hostId': 'host-1',
          'participants': ['host-1', 'guest-1'],
          'status': 'active',
          'mode': 'turn_based',
          'createdAt': Timestamp.now(),
          'startedAt': Timestamp.now(),
        });

        final session = Session.fromFirestore(doc);

        expect(session.phase, SessionPhase.live);
      },
    );
  });

  group('areAllJoinedGymParticipantsReady', () {
    test('returns true when all joined participants are ready', () {
      final participants = ['host-1', 'guest-1'];
      final plans = <String, GymSessionPlan>{
        'host-1': GymSessionPlan(
          userId: 'host-1',
          source: GymSessionPlanSource.personal,
          isReady: true,
          exercises: const [],
        ),
        'guest-1': GymSessionPlan(
          userId: 'guest-1',
          source: GymSessionPlanSource.personal,
          isReady: true,
          exercises: const [],
        ),
      };

      final result = areAllJoinedGymParticipantsReady(
        participants: participants,
        plans: plans,
      );

      expect(result, isTrue);
    });

    test('returns false when any joined participant is not ready', () {
      final participants = ['host-1', 'guest-1'];
      final plans = <String, GymSessionPlan>{
        'host-1': GymSessionPlan(
          userId: 'host-1',
          source: GymSessionPlanSource.personal,
          isReady: true,
          exercises: const [],
        ),
        'guest-1': GymSessionPlan(
          userId: 'guest-1',
          source: GymSessionPlanSource.personal,
          isReady: false,
          exercises: const [],
        ),
      };

      final result = areAllJoinedGymParticipantsReady(
        participants: participants,
        plans: plans,
      );

      expect(result, isFalse);
    });
  });
}
