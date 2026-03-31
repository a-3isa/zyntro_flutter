import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/session/domain/gym_session_plan.dart';
import 'package:zyntro_flutter/services/session_service.dart';
import 'package:zyntro_flutter/services/user_cache_service.dart';
import 'package:zyntro_flutter/services/notification_service.dart';

// Mocks
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockRef extends Mock implements Ref {}

class MockUserCacheService extends Mock implements UserCacheService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockBatch extends Mock implements WriteBatch {}

class MockTransaction extends Mock implements Transaction {}

// ignore: subtype_of_sealed_class
class FakeDocumentReferenceObject extends Fake
    implements DocumentReference<Object?> {}

void main() {
  late SessionService sessionService;
  late MockFirebaseFirestore mockFirestore;
  late MockRef mockRef;
  late MockUserCacheService mockUserCacheService;
  late MockNotificationService mockNotificationService;
  late MockCollectionReference mockSessionsCollection;
  late MockDocumentReference mockSessionDoc;
  late MockBatch mockBatch;
  late MockTransaction mockTransaction;

  setUpAll(() {
    registerFallbackValue(FakeDocumentReferenceObject());
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockRef = MockRef();
    mockUserCacheService = MockUserCacheService();
    mockNotificationService = MockNotificationService();
    mockSessionsCollection = MockCollectionReference();
    mockSessionDoc = MockDocumentReference();
    mockBatch = MockBatch();
    mockTransaction = MockTransaction();

    // Setup Ref
    when(
      () => mockRef.read(userCacheServiceProvider),
    ).thenReturn(mockUserCacheService);
    when(
      () => mockRef.read(notificationServiceProvider),
    ).thenReturn(mockNotificationService);

    // Setup Firestore
    when(
      () => mockFirestore.collection(any()),
    ).thenReturn(mockSessionsCollection);
    when(() => mockFirestore.batch()).thenReturn(mockBatch);
    when(() => mockSessionsCollection.doc(any())).thenReturn(mockSessionDoc);
    when(
      () => mockSessionDoc.collection(any()),
    ).thenReturn(mockSessionsCollection); // Simplified
    when(() => mockSessionDoc.update(any())).thenAnswer((_) async {});
    when(() => mockSessionDoc.set(any())).thenAnswer((_) async {});
    when(() => mockBatch.commit()).thenAnswer((_) async {});
    when(() => mockFirestore.runTransaction<void>(any())).thenAnswer((
      invocation,
    ) async {
      final callback =
          invocation.positionalArguments[0]
              as Future<void> Function(Transaction);
      return callback(mockTransaction);
    });
    when(() => mockFirestore.runTransaction<dynamic>(any())).thenAnswer((
      invocation,
    ) async {
      final callback =
          invocation.positionalArguments[0]
              as Future<dynamic> Function(Transaction);
      return callback(mockTransaction);
    });

    // Setup ID generation
    when(() => mockSessionDoc.id).thenReturn('test_session_id');

    // Default stubs
    when(
      () => mockUserCacheService.warmSessionParticipants(any()),
    ).thenAnswer((_) async {});

    sessionService = SessionService(mockFirestore, mockRef);
  });

  group('SessionService', () {
    test('createSession creates a new session and notifies invitees', () async {
      final hostId = 'host_123';
      final invitees = ['user_456'];

      // Mock User Cache
      when(() => mockUserCacheService.getUser(hostId)).thenAnswer(
        (_) async => User(
          id: hostId,
          displayName: 'Host',
          photoURL: null,
          isPrivate: false,
          workoutPreference: WorkoutType.other,
          beginnerFlag: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      when(() => mockUserCacheService.getUser('user_456')).thenAnswer(
        (_) async => User(
          id: 'user_456',
          displayName: 'Invitee',
          photoURL: null,
          isPrivate: false,
          workoutPreference: WorkoutType.other,
          beginnerFlag: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Mock Active Session Check (return empty query)
      final mockQuery = MockQuery();
      final mockSnapshot = MockQuerySnapshot();
      when(
        () =>
            mockSessionsCollection.where('participants', arrayContains: hostId),
      ).thenReturn(mockQuery);
      when(
        () => mockQuery.where('status', isEqualTo: 'active'),
      ).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs).thenReturn([]);

      // Mock notifications
      when(
        () => mockNotificationService.notifySessionInvite(
          recipientId: any(named: 'recipientId'),
          inviterName: any(named: 'inviterName'),
          sessionId: any(named: 'sessionId'),
          sessionType: any(named: 'sessionType'),
          groupSize: any(named: 'groupSize'),
          otherParticipantNames: any(named: 'otherParticipantNames'),
        ),
      ).thenAnswer((_) async {});

      // Act
      final sessionId = await sessionService.createSession(
        hostId: hostId,
        type: 'strength',
        title: 'Morning Workout',
        invitedUserIds: invitees,
        mode: SessionMode.turnBased,
      );

      // Assert
      expect(sessionId, 'test_session_id');
      verify(() => mockBatch.commit()).called(1);
      verify(
        () => mockNotificationService.notifySessionInvite(
          recipientId: 'user_456',
          inviterName: 'Host',
          sessionId: 'test_session_id',
          sessionType: 'strength',
          groupSize: any(named: 'groupSize'),
          otherParticipantNames: any(named: 'otherParticipantNames'),
        ),
      ).called(1);
    });

    test('switchTurn updates activeUserId', () async {
      final sessionId = 'session_123';
      final currentUserId = 'user_1';
      final otherUserId = 'user_2';

      // Mock getSession
      final mockDocSnapshot = MockDocumentSnapshot();
      when(() => mockSessionDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(true);
      when(() => mockDocSnapshot.data()).thenReturn({
        'id': sessionId,
        'hostId': 'user_1',
        'title': 'Test',
        'type': 'strength',
        'status': 'active',
        'participants': [currentUserId, otherUserId],
        'mode': 'turn_based',
        'activeUserId': currentUserId,
        'createdAt': Timestamp.now(),
        'startedAt': Timestamp.now(),
      });
      when(() => mockDocSnapshot.id).thenReturn(sessionId);

      // Mock User Cache for next user
      when(() => mockUserCacheService.getUser(otherUserId)).thenAnswer(
        (_) async => User(
          id: otherUserId,
          displayName: 'Next User',
          photoURL: null,
          isPrivate: false,
          workoutPreference: WorkoutType.other,
          beginnerFlag: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Mock turn notification
      when(
        () => mockNotificationService.notifyTurnChange(
          recipientId: any(named: 'recipientId'),
          sessionId: any(named: 'sessionId'),
          sessionType: any(named: 'sessionType'),
        ),
      ).thenAnswer((_) async {});

      // Act
      await sessionService.switchTurn(sessionId, currentUserId);

      // Assert
      verify(
        () => mockSessionDoc.update({'activeUserId': otherUserId}),
      ).called(1);
    });

    test('createSession stores setup phase when requested', () async {
      final hostId = 'host_123';

      when(() => mockUserCacheService.getUser(hostId)).thenAnswer(
        (_) async => User(
          id: hostId,
          displayName: 'Host',
          photoURL: null,
          isPrivate: false,
          workoutPreference: WorkoutType.other,
          beginnerFlag: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final mockQuery = MockQuery();
      final mockSnapshot = MockQuerySnapshot();
      when(
        () =>
            mockSessionsCollection.where('participants', arrayContains: hostId),
      ).thenReturn(mockQuery);
      when(
        () => mockQuery.where('status', isEqualTo: 'active'),
      ).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs).thenReturn([]);

      await sessionService.createSession(
        hostId: hostId,
        type: 'gym',
        title: 'Gym Setup',
        phase: SessionPhase.setup,
      );

      final capturedPayloads =
          verify(
                () => mockBatch.set<Map<String, Object?>>(
                  mockSessionDoc,
                  captureAny(),
                  any(),
                ),
              ).captured
              .whereType<Map<String, Object?>>()
              .toList();
      expect(
        capturedPayloads.any(
          (payload) => payload['phase'] == SessionPhase.setup.value,
        ),
        isTrue,
      );
    });

    test('createSession defaults phase to live', () async {
      final hostId = 'host_123';

      when(() => mockUserCacheService.getUser(hostId)).thenAnswer(
        (_) async => User(
          id: hostId,
          displayName: 'Host',
          photoURL: null,
          isPrivate: false,
          workoutPreference: WorkoutType.other,
          beginnerFlag: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final mockQuery = MockQuery();
      final mockSnapshot = MockQuerySnapshot();
      when(
        () =>
            mockSessionsCollection.where('participants', arrayContains: hostId),
      ).thenReturn(mockQuery);
      when(
        () => mockQuery.where('status', isEqualTo: 'active'),
      ).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs).thenReturn([]);

      await sessionService.createSession(
        hostId: hostId,
        type: 'gym',
        title: 'Live Gym Session',
      );

      final capturedPayloads =
          verify(
                () => mockBatch.set<Map<String, Object?>>(
                  mockSessionDoc,
                  captureAny(),
                  any(),
                ),
              ).captured
              .whereType<Map<String, Object?>>()
              .toList();
      expect(
        capturedPayloads.any(
          (payload) => payload['phase'] == SessionPhase.live.value,
        ),
        isTrue,
      );
    });

    test('createSession seeds an empty host template for setup sessions', () async {
      final hostId = 'host_123';
      final mockPlansCollection = MockCollectionReference();
      final mockHostPlanDoc = MockDocumentReference();

      when(() => mockUserCacheService.getUser(hostId)).thenAnswer(
        (_) async => User(
          id: hostId,
          displayName: 'Host',
          photoURL: null,
          isPrivate: false,
          workoutPreference: WorkoutType.other,
          beginnerFlag: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final mockQuery = MockQuery();
      final mockSnapshot = MockQuerySnapshot();
      when(
        () =>
            mockSessionsCollection.where('participants', arrayContains: hostId),
      ).thenReturn(mockQuery);
      when(
        () => mockQuery.where('status', isEqualTo: 'active'),
      ).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs).thenReturn([]);

      when(() => mockSessionDoc.collection('plans')).thenReturn(mockPlansCollection);
      when(() => mockPlansCollection.doc(hostId)).thenReturn(mockHostPlanDoc);

      await sessionService.createSession(
        hostId: hostId,
        type: 'gym',
        title: 'Gym Setup',
        phase: SessionPhase.setup,
      );

      verify(
        () => mockBatch.set<Map<String, dynamic>>(
          mockHostPlanDoc,
          any(
            that: isA<Map<String, dynamic>>()
                .having((m) => m['userId'], 'userId', hostId)
                .having(
                  (m) => m['source'],
                  'source',
                  GymSessionPlanSource.hostTemplate.value,
                )
                .having((m) => m['isReady'], 'isReady', false)
                .having((m) => m['exercises'], 'exercises', isEmpty),
          ),
          any(),
        ),
      ).called(1);
    });

    test('saveGymPlan persists the user plan document', () async {
      const sessionId = 'session_123';
      const userId = 'user_456';
      final mockPlansCollection = MockCollectionReference();
      final mockUserPlanDoc = MockDocumentReference();
      final plan = GymSessionPlan(
        userId: userId,
        source: GymSessionPlanSource.personal,
        isReady: false,
        exercises: [
          PlannedExercise.custom(
            id: 'custom_1',
            name: 'JM Press',
            plannedSets: 3,
            order: 0,
          ),
        ],
      );

      when(() => mockSessionDoc.collection('plans')).thenReturn(mockPlansCollection);
      when(() => mockPlansCollection.doc(userId)).thenReturn(mockUserPlanDoc);
      when(() => mockUserPlanDoc.set(any())).thenAnswer((_) async {});

      await sessionService.saveGymPlan(sessionId: sessionId, plan: plan);

      verify(() => mockUserPlanDoc.set(plan.toMap())).called(1);
    });

    test('ensureGymPlan clones host template when participant plan is missing', () async {
      const sessionId = 'session_123';
      const hostId = 'host_123';
      const userId = 'user_456';

      final mockPlansCollection = MockCollectionReference();
      final mockHostPlanDoc = MockDocumentReference();
      final mockUserPlanDoc = MockDocumentReference();
      final mockHostPlanSnapshot = MockDocumentSnapshot();
      final mockUserPlanSnapshot = MockDocumentSnapshot();

      when(
        () => mockSessionDoc.collection('plans'),
      ).thenReturn(mockPlansCollection);
      when(() => mockPlansCollection.doc(hostId)).thenReturn(mockHostPlanDoc);
      when(() => mockPlansCollection.doc(userId)).thenReturn(mockUserPlanDoc);
      when(() => mockUserPlanDoc.get()).thenAnswer((_) async => mockUserPlanSnapshot);
      when(() => mockHostPlanDoc.get()).thenAnswer((_) async => mockHostPlanSnapshot);
      when(() => mockUserPlanSnapshot.exists).thenReturn(false);
      when(() => mockHostPlanSnapshot.exists).thenReturn(true);
      when(() => mockHostPlanSnapshot.data()).thenReturn({
        'userId': hostId,
        'source': GymSessionPlanSource.hostTemplate.value,
        'isReady': true,
        'exercises': [
          {
            'id': 'ex_1',
            'sourceType': PlannedExerciseSource.catalog.value,
            'exerciseId': 'bench_press',
            'name': 'Bench Press',
            'plannedSets': 4,
            'order': 0,
          },
        ],
      });
      when(() => mockUserPlanDoc.set(any())).thenAnswer((_) async {});

      final result = await sessionService.ensureGymPlan(
        sessionId: sessionId,
        hostId: hostId,
        userId: userId,
      );

      expect(result.userId, userId);
      expect(result.source, GymSessionPlanSource.personal);
      expect(result.isReady, false);
      expect(result.exercises.length, 1);
      verify(
        () => mockUserPlanDoc.set(
          any(
            that: isA<Map<String, dynamic>>()
                .having((m) => m['userId'], 'userId', userId)
                .having(
                  (m) => m['source'],
                  'source',
                  GymSessionPlanSource.personal.value,
                )
                .having((m) => m['isReady'], 'isReady', false),
          ),
        ),
      ).called(1);
    });

    test('listenToGymPlan emits decoded user plans', () async {
      const sessionId = 'session_123';
      const userId = 'user_456';
      final mockPlansCollection = MockCollectionReference();
      final mockUserPlanDoc = MockDocumentReference();
      final mockUserPlanSnapshot = MockDocumentSnapshot();
      const encodedPlan = {
        'userId': userId,
        'source': 'personal',
        'isReady': true,
        'exercises': [
          {
            'id': 'custom_1',
            'sourceType': 'custom',
            'name': 'JM Press',
            'plannedSets': 3,
            'order': 0,
          },
        ],
      };

      when(() => mockSessionDoc.collection('plans')).thenReturn(mockPlansCollection);
      when(() => mockPlansCollection.doc(userId)).thenReturn(mockUserPlanDoc);
      when(
        () => mockUserPlanDoc.snapshots(),
      ).thenAnswer((_) => Stream.value(mockUserPlanSnapshot));
      when(() => mockUserPlanSnapshot.exists).thenReturn(true);
      when(() => mockUserPlanSnapshot.data()).thenReturn(encodedPlan);

      final emittedPlan = await sessionService
          .listenToGymPlan(sessionId, userId)
          .first;

      expect(emittedPlan, isNotNull);
      expect(emittedPlan!.userId, userId);
      expect(emittedPlan.isReady, isTrue);
      expect(emittedPlan.exercises.single.name, 'JM Press');
    });

    test('setGymPlanReady promotes session to live when all participants are ready', () async {
      const sessionId = 'session_123';
      const userId = 'user_1';
      const otherUserId = 'user_2';

      final mockPlansCollection = MockCollectionReference();
      final mockUserPlanDoc = MockDocumentReference();
      final mockOtherPlanDoc = MockDocumentReference();
      final mockSessionSnapshot = MockDocumentSnapshot();
      final mockUserPlanSnapshot = MockDocumentSnapshot();
      final mockOtherPlanSnapshot = MockDocumentSnapshot();

      when(
        () => mockSessionDoc.collection('plans'),
      ).thenReturn(mockPlansCollection);
      when(() => mockPlansCollection.doc(userId)).thenReturn(mockUserPlanDoc);
      when(
        () => mockPlansCollection.doc(otherUserId),
      ).thenReturn(mockOtherPlanDoc);

      when(() => mockTransaction.get(mockSessionDoc)).thenAnswer(
        (_) async => mockSessionSnapshot,
      );
      when(() => mockTransaction.get(mockUserPlanDoc)).thenAnswer(
        (_) async => mockUserPlanSnapshot,
      );
      when(() => mockTransaction.get(mockOtherPlanDoc)).thenAnswer(
        (_) async => mockOtherPlanSnapshot,
      );
      when(() => mockSessionSnapshot.data()).thenReturn({
        'participants': [userId, otherUserId],
        'phase': SessionPhase.setup.value,
      });
      when(() => mockUserPlanSnapshot.exists).thenReturn(true);
      when(() => mockOtherPlanSnapshot.exists).thenReturn(true);
      when(() => mockUserPlanSnapshot.data()).thenReturn({
        'userId': userId,
        'source': GymSessionPlanSource.personal.value,
        'isReady': false,
        'exercises': const [],
      });
      when(() => mockOtherPlanSnapshot.data()).thenReturn({
        'userId': otherUserId,
        'source': GymSessionPlanSource.personal.value,
        'isReady': true,
        'exercises': const [],
      });
      when(
        () => mockTransaction.update(any(), any()),
      ).thenAnswer((_) => mockTransaction);

      await sessionService.setGymPlanReady(
        sessionId: sessionId,
        userId: userId,
        isReady: true,
      );

      verify(
        () => mockTransaction.update(mockUserPlanDoc, {'isReady': true}),
      ).called(1);
      verify(
        () => mockTransaction.update(mockSessionDoc, {
          'phase': SessionPhase.live.value,
        }),
      ).called(1);
    });

    test('setGymPlanReady does not re-promote sessions that are already live', () async {
      const sessionId = 'session_123';
      const userId = 'user_1';
      const otherUserId = 'user_2';

      final mockPlansCollection = MockCollectionReference();
      final mockUserPlanDoc = MockDocumentReference();
      final mockOtherPlanDoc = MockDocumentReference();
      final mockSessionSnapshot = MockDocumentSnapshot();
      final mockUserPlanSnapshot = MockDocumentSnapshot();
      final mockOtherPlanSnapshot = MockDocumentSnapshot();

      when(() => mockSessionDoc.collection('plans')).thenReturn(mockPlansCollection);
      when(() => mockPlansCollection.doc(userId)).thenReturn(mockUserPlanDoc);
      when(() => mockPlansCollection.doc(otherUserId)).thenReturn(mockOtherPlanDoc);
      when(
        () => mockTransaction.get(mockSessionDoc),
      ).thenAnswer((_) async => mockSessionSnapshot);
      when(
        () => mockTransaction.get(mockUserPlanDoc),
      ).thenAnswer((_) async => mockUserPlanSnapshot);
      when(
        () => mockTransaction.get(mockOtherPlanDoc),
      ).thenAnswer((_) async => mockOtherPlanSnapshot);
      when(() => mockSessionSnapshot.data()).thenReturn({
        'participants': [userId, otherUserId],
        'phase': SessionPhase.live.value,
      });
      when(() => mockUserPlanSnapshot.exists).thenReturn(true);
      when(() => mockOtherPlanSnapshot.exists).thenReturn(true);
      when(() => mockUserPlanSnapshot.data()).thenReturn({
        'userId': userId,
        'source': GymSessionPlanSource.personal.value,
        'isReady': false,
        'exercises': const [],
      });
      when(() => mockOtherPlanSnapshot.data()).thenReturn({
        'userId': otherUserId,
        'source': GymSessionPlanSource.personal.value,
        'isReady': true,
        'exercises': const [],
      });
      when(
        () => mockTransaction.update(any(), any()),
      ).thenAnswer((_) => mockTransaction);

      await sessionService.setGymPlanReady(
        sessionId: sessionId,
        userId: userId,
        isReady: true,
      );

      verify(
        () => mockTransaction.update(mockUserPlanDoc, {'isReady': true}),
      ).called(1);
      verifyNever(
        () => mockTransaction.update(mockSessionDoc, {
          'phase': SessionPhase.live.value,
        }),
      );
    });

    test('setGymPlanReady rejects missing plans instead of creating empty ready plans', () async {
      const sessionId = 'session_123';
      const userId = 'user_1';

      final mockPlansCollection = MockCollectionReference();
      final mockUserPlanDoc = MockDocumentReference();
      final mockSessionSnapshot = MockDocumentSnapshot();
      final mockUserPlanSnapshot = MockDocumentSnapshot();

      when(() => mockSessionDoc.collection('plans')).thenReturn(mockPlansCollection);
      when(() => mockPlansCollection.doc(userId)).thenReturn(mockUserPlanDoc);
      when(
        () => mockTransaction.get(mockSessionDoc),
      ).thenAnswer((_) async => mockSessionSnapshot);
      when(
        () => mockTransaction.get(mockUserPlanDoc),
      ).thenAnswer((_) async => mockUserPlanSnapshot);
      when(() => mockSessionSnapshot.data()).thenReturn({
        'participants': [userId],
        'phase': SessionPhase.setup.value,
      });
      when(() => mockUserPlanSnapshot.exists).thenReturn(false);
      when(() => mockUserPlanSnapshot.data()).thenReturn(null);

      expect(
        () => sessionService.setGymPlanReady(
          sessionId: sessionId,
          userId: userId,
          isReady: true,
        ),
        throwsA(isA<StateError>()),
      );

      verifyNever(() => mockTransaction.set(any(), any()));
      verifyNever(() => mockTransaction.update(mockSessionDoc, any()));
    });
  });
}
