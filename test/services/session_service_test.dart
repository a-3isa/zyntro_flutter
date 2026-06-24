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
import 'package:zyntro_flutter/services/session_analytics_service.dart';
import 'package:zyntro_flutter/services/follow_service.dart';

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

class MockSessionAnalyticsService extends Mock
    implements SessionAnalyticsService {}

class MockFollowService extends Mock implements FollowService {}

class MockBatch extends Mock implements WriteBatch {}

// ignore: subtype_of_sealed_class
class FakeDocumentReferenceObject extends Fake
    implements DocumentReference<Object?> {}

// ignore: subtype_of_sealed_class
class FakeDocumentReferenceMap extends Fake
    implements DocumentReference<Map<String, dynamic>> {}

const kPairedHostId = 'host_123';
const kPairedFriendId = 'user_456';
const kPairedBotId = 'zyntro_bot_friend';
const kPairedSessionId = 'test_session_id';

User buildSessionTestUser({
  required String id,
  String displayName = 'Athlete',
  WorkoutType workoutPreference = WorkoutType.other,
}) {
  return User(
    id: id,
    displayName: displayName,
    photoURL: null,
    isPrivate: false,
    workoutPreference: workoutPreference,
    beginnerFlag: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

Map<String, dynamic> buildPairedSessionData({
  String hostId = kPairedHostId,
  String partnerId = kPairedFriendId,
  List<String>? participants,
  Map<String, String>? participantTypes,
  String type = 'gym',
  String phase = 'live',
  String status = 'active',
  String? activeUserId,
}) {
  final resolvedParticipants = participants ?? [hostId, partnerId];
  return {
    'hostId': hostId,
    'partnerId': partnerId,
    'title': 'Paired Workout',
    'type': type,
    'status': status,
    'participants': resolvedParticipants,
    'activeUserId': activeUserId ?? hostId,
    'phase': phase,
    'participantTypes':
        participantTypes ??
        {for (final participantId in resolvedParticipants) participantId: type},
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'startedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  };
}

void main() {
  late SessionService sessionService;
  late MockFirebaseFirestore mockFirestore;
  late MockRef mockRef;
  late MockUserCacheService mockUserCacheService;
  late MockNotificationService mockNotificationService;
  late MockSessionAnalyticsService mockSessionAnalyticsService;
  late MockFollowService mockFollowService;
  late MockCollectionReference mockSessionsCollection;
  late MockDocumentReference mockSessionDoc;
  late MockBatch mockBatch;

  setUpAll(() {
    registerFallbackValue(FakeDocumentReferenceObject());
    registerFallbackValue(FakeDocumentReferenceMap());
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockRef = MockRef();
    mockUserCacheService = MockUserCacheService();
    mockNotificationService = MockNotificationService();
    mockSessionAnalyticsService = MockSessionAnalyticsService();
    mockFollowService = MockFollowService();
    mockSessionsCollection = MockCollectionReference();
    mockSessionDoc = MockDocumentReference();
    mockBatch = MockBatch();

    // Setup Ref
    when(
      () => mockRef.read(userCacheServiceProvider),
    ).thenReturn(mockUserCacheService);
    when(
      () => mockRef.read(notificationServiceProvider),
    ).thenReturn(mockNotificationService);
    when(
      () => mockRef.read(sessionAnalyticsServiceProvider),
    ).thenReturn(mockSessionAnalyticsService);
    when(
      () => mockRef.read(followServiceProvider),
    ).thenReturn(mockFollowService);

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

    // Setup ID generation
    when(() => mockSessionDoc.id).thenReturn('test_session_id');

    // Default stubs
    when(
      () => mockUserCacheService.warmSessionParticipants(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockSessionAnalyticsService.trackPairedSessionEvent(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockFollowService.canInviteToPairedSession(
        hostId: any(named: 'hostId'),
        inviteeId: any(named: 'inviteeId'),
      ),
    ).thenAnswer((_) async => true);

    sessionService = SessionService(mockFirestore, mockRef);
  });

  group('SessionService', () {
    test('paired validation requires exactly two participants', () {
      expect(
        () => SessionService.validatePairedParticipants(['host']),
        throwsArgumentError,
      );
      expect(
        () => SessionService.validatePairedParticipants([
          'host',
          'friend',
          'extra',
        ]),
        throwsArgumentError,
      );

      expect(SessionService.validatePairedParticipants(['host', 'friend']), [
        'host',
        'friend',
      ]);
    });

    test('matching gym is turn-based and mixed types are parallel', () {
      expect(
        SessionService.derivePairedSessionMode(const {
          'host': 'gym',
          'friend': 'gym',
        }),
        SessionMode.turnBased,
      );
      expect(
        SessionService.derivePairedSessionMode(const {
          'host': 'gym',
          'friend': 'running',
        }),
        SessionMode.parallel,
      );
    });

    test('mixed workout type sessions derive mode without starting clock', () {
      final fields = SessionService.sharedClockStartFields(
        participantTypes: const {
          kPairedHostId: 'gym',
          kPairedFriendId: 'running',
        },
      );

      expect(fields['mode'], SessionMode.parallel.value);
      expect(fields, isNot(contains('sharedClockStartedAt')));
      expect(fields['participantTypes'], {
        kPairedHostId: 'gym',
        kPairedFriendId: 'running',
      });
    });

    test(
      'plan ownership requires the requester to own the participant plan',
      () {
        expect(
          SessionService.isParticipantPlanOwner(
            planUserId: kPairedFriendId,
            requesterId: kPairedFriendId,
          ),
          isTrue,
        );
        expect(
          SessionService.isParticipantPlanOwner(
            planUserId: kPairedFriendId,
            requesterId: kPairedHostId,
          ),
          isFalse,
        );
      },
    );

    test('copies host gym plan into an isolated invited-user draft', () {
      final hostPlan = GymSessionPlan(
        userId: kPairedHostId,
        source: GymSessionPlanSource.hostTemplate,
        isReady: true,
        exercises: [
          PlannedExercise.custom(
            id: 'host-bench',
            name: 'Bench Press',
            plannedSets: 4,
            order: 0,
            muscleGroup: 'Chest',
          ),
        ],
      );

      final invitedPlan = SessionService.copyHostGymPlanForInvitee(
        hostPlan: hostPlan,
        inviteeId: kPairedFriendId,
      );

      expect(invitedPlan.userId, kPairedFriendId);
      expect(invitedPlan.source, GymSessionPlanSource.personalCopy);
      expect(invitedPlan.isReady, isFalse);
      expect(invitedPlan.exercises.single.name, 'Bench Press');
      expect(invitedPlan.exercises.single.plannedSets, 4);
      expect(identical(invitedPlan.exercises, hostPlan.exercises), isFalse);

      final modifiedInviteeExercise = PlannedExercise.custom(
        id: invitedPlan.exercises.single.id,
        name: 'Bench Press',
        plannedSets: 2,
        order: 0,
        muscleGroup: 'Chest',
      );
      final modifiedInviteePlan = GymSessionPlan(
        userId: invitedPlan.userId,
        source: invitedPlan.source,
        isReady: true,
        exercises: [modifiedInviteeExercise],
      );

      expect(modifiedInviteePlan.exercises.single.plannedSets, 2);
      expect(hostPlan.exercises.single.plannedSets, 4);
    });

    test(
      'builds per-participant completion history with owner type and plan',
      () {
        final plan = GymSessionPlan(
          userId: kPairedFriendId,
          workoutType: WorkoutType.running,
          source: GymSessionPlanSource.personal,
          isReady: true,
          exercises: const [],
          stages: const [
            PlannedWorkoutStage(
              id: 'run-stage',
              label: 'Run',
              targetKind: PlanTargetKind.distance,
              targetValue: 3,
            ),
          ],
          targets: const {'distanceKm': 3},
        );
        final progress = ParticipantProgress(
          sessionId: kPairedSessionId,
          userId: kPairedFriendId,
          workoutType: WorkoutType.running,
          status: ParticipantProgressStatus.completed,
          sharedElapsedSeconds: 900,
          distanceMetrics: const DistanceProgressMetrics(distanceKm: 3),
          updatedAt: DateTime(2026, 5, 27, 12, 15),
        );

        final record = SessionService.participantCompletionRecord(
          sessionId: kPairedSessionId,
          userId: kPairedFriendId,
          plan: plan,
          progress: progress,
        );

        expect(record['sessionId'], kPairedSessionId);
        expect(record['userId'], kPairedFriendId);
        expect(record['workoutType'], WorkoutType.running.value);
        expect(record['plan']['targets']['distanceKm'], 3);
        expect(record['progress']['distanceMetrics']['distanceKm'], 3);
      },
    );

    test('creates a bot paired session without invitation delivery', () async {
      when(() => mockUserCacheService.getUser(kPairedHostId)).thenAnswer(
        (_) async =>
            buildSessionTestUser(id: kPairedHostId, displayName: 'Host'),
      );
      final hostPlan = GymSessionPlan(
        userId: kPairedHostId,
        source: GymSessionPlanSource.hostTemplate,
        isReady: true,
        exercises: [
          PlannedExercise.custom(
            id: 'bench',
            name: 'Bench Press',
            plannedSets: 2,
            order: 0,
          ),
        ],
      );

      final mockQuery = MockQuery();
      final mockSnapshot = MockQuerySnapshot();
      when(
        () => mockSessionsCollection.where(
          'participants',
          arrayContains: kPairedHostId,
        ),
      ).thenReturn(mockQuery);
      when(
        () => mockQuery.where('status', isEqualTo: 'active'),
      ).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs).thenReturn([]);

      final sessionId = await sessionService.createBotPairedSession(
        hostId: kPairedHostId,
        type: WorkoutType.gym.value,
        title: 'Bot Gym',
        plan: hostPlan,
      );

      expect(sessionId, kPairedSessionId);
      verifyNever(
        () => mockNotificationService.notifySessionInvite(
          recipientId: any(named: 'recipientId'),
          inviterName: any(named: 'inviterName'),
          sessionId: any(named: 'sessionId'),
          sessionType: any(named: 'sessionType'),
          hostId: any(named: 'hostId'),
          expiresAt: any(named: 'expiresAt'),
          groupSize: any(named: 'groupSize'),
          otherParticipantNames: any(named: 'otherParticipantNames'),
        ),
      );
      final capturedWrites = verify(
        () => mockBatch.set<Map<String, dynamic>>(any(), captureAny(), null),
      ).captured.cast<Map<String, dynamic>>();
      final sessionData = capturedWrites.firstWhere(
        (write) => write['partnerKind'] == 'bot',
      );
      final hostPlanData = capturedWrites.firstWhere(
        (write) => write['userId'] == kPairedHostId,
      );
      final botPlanData = capturedWrites.firstWhere(
        (write) => write['userId'] == pairedBotFriendId,
      );
      expect(sessionData['partnerKind'], 'bot');
      expect(sessionData['partnerId'], pairedBotFriendId);
      expect(sessionData['participants'], [kPairedHostId, pairedBotFriendId]);
      expect(sessionData['mode'], SessionMode.turnBased.value);
      expect(hostPlanData['exercises'].single['plannedSets'], 2);
      expect(botPlanData['exercises'].single['name'], 'Bench Press');
      expect(botPlanData['exercises'].single['plannedSets'], 2);
    });

    test('real friend session allows exactly one eligible invitee', () {
      expect(
        () => SessionService.validateOneToOneInvitees(null),
        returnsNormally,
      );
      expect(
        () => SessionService.validateOneToOneInvitees([kPairedFriendId]),
        returnsNormally,
      );
      expect(
        () => SessionService.validateOneToOneInvitees([
          kPairedFriendId,
          'user-789',
        ]),
        throwsArgumentError,
      );
    });

    test('late invite acceptance is rejected after expiry', () async {
      final expiredDoc = MockDocumentSnapshot();
      when(() => mockSessionDoc.get()).thenAnswer((_) async => expiredDoc);
      when(() => expiredDoc.exists).thenReturn(true);
      when(() => expiredDoc.data()).thenReturn({
        'inviteExpiresAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      });

      expect(
        () => sessionService.acceptInvite(
          sessionId: kPairedSessionId,
          userId: kPairedFriendId,
          chosenWorkoutType: WorkoutType.gym.value,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('joinSetup adds the invitee in setup without going live', () async {
      // Arrange: pending, non-expired invite session in setup phase
      final sessionDoc = MockDocumentSnapshot();
      when(() => mockSessionDoc.get()).thenAnswer((_) async => sessionDoc);
      when(() => sessionDoc.exists).thenReturn(true);
      when(() => sessionDoc.data()).thenReturn({
        'hostId': kPairedHostId,
        'participants': [kPairedHostId],
        'invitedUserIds': [kPairedFriendId],
        'invitationStatus': WorkoutInvitationStatus.pending.value,
        'inviteExpiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 10)),
        ),
        'phase': SessionPhase.setup.value,
        'status': SessionStatus.active.value,
        'type': 'gym',
      });

      when(() => mockUserCacheService.getUser(kPairedFriendId)).thenAnswer(
        (_) async => buildSessionTestUser(
          id: kPairedFriendId,
          displayName: 'Friend',
        ),
      );

      // Act
      await sessionService.joinSetup(
        sessionId: kPairedSessionId,
        userId: kPairedFriendId,
        chosenWorkoutType: WorkoutType.gym.value,
      );

      // Assert: batch was committed
      verify(() => mockBatch.commit()).called(1);

      // Assert: batch.update was called with participants arrayUnion + participantTypes + invitationStatus
      final capturedUpdates = verify(
        () => mockBatch.update(any(), captureAny()),
      ).captured.cast<Map<String, dynamic>>();

      expect(capturedUpdates, isNotEmpty);
      final updateData = capturedUpdates.first;
      expect(updateData['invitationStatus'], WorkoutInvitationStatus.accepted.value);
      expect(
        updateData['participantTypes.$kPairedFriendId'],
        WorkoutType.gym.value,
      );
      // Verify participants arrayUnion is present
      expect(updateData.containsKey('participants'), isTrue);
      expect(updateData['participants'], isA<FieldValue>());
      // Verify phase was NOT changed (no 'phase' key in the update)
      expect(updateData.containsKey('phase'), isFalse);
      expect(updateData.containsKey('status'), isFalse);

      // Assert: a plan stub (set) was written with isReady: false
      final capturedSets = verify(
        () => mockBatch.set<Map<String, dynamic>>(any(), captureAny(), null),
      ).captured.cast<Map<String, dynamic>>();

      final planData = capturedSets.firstWhere(
        (d) => d.containsKey('isReady'),
        orElse: () => <String, dynamic>{},
      );
      expect(planData['isReady'], isFalse);
      expect(planData['userId'], kPairedFriendId);
    });

    test('joinSetup rejects a non-invited user', () async {
      // invitedUserIds contains someone else, not kPairedFriendId
      final sessionDoc = MockDocumentSnapshot();
      when(() => mockSessionDoc.get()).thenAnswer((_) async => sessionDoc);
      when(() => sessionDoc.exists).thenReturn(true);
      when(() => sessionDoc.data()).thenReturn({
        'hostId': kPairedHostId,
        'participants': [kPairedHostId],
        'invitedUserIds': ['someone_else'],
        'invitationStatus': WorkoutInvitationStatus.pending.value,
        'inviteExpiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 10)),
        ),
        'phase': SessionPhase.setup.value,
        'status': SessionStatus.active.value,
        'type': 'gym',
      });

      await expectLater(
        () => sessionService.joinSetup(
          sessionId: kPairedSessionId,
          userId: kPairedFriendId,
          chosenWorkoutType: WorkoutType.gym.value,
        ),
        throwsA(isA<Exception>()),
      );
    });

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
          hostId: any(named: 'hostId'),
          expiresAt: any(named: 'expiresAt'),
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
          hostId: hostId,
          expiresAt: any(named: 'expiresAt'),
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
        'type': 'gym',
        'status': 'active',
        'participants': [currentUserId, otherUserId],
        'participantTypes': {currentUserId: 'gym', otherUserId: 'gym'},
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

    test('endSession only updates caller user stats from the client', () async {
      final mockDocSnapshot = MockDocumentSnapshot();
      when(() => mockSessionDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(true);
      when(() => mockDocSnapshot.id).thenReturn(kPairedSessionId);
      when(() => mockDocSnapshot.data()).thenReturn(buildPairedSessionData());

      await sessionService.endSession(kPairedSessionId, kPairedHostId, null);

      verify(() => mockSessionsCollection.doc(kPairedHostId)).called(1);
      verifyNever(() => mockSessionsCollection.doc(kPairedFriendId));
      verify(() => mockBatch.commit()).called(1);
    });

    test('cancelSetup writes the audit fields and keeps roster intact',
        () async {
      Map<Object, Object?>? capturedUpdate;
      when(() => mockSessionDoc.update(any())).thenAnswer((invocation) async {
        capturedUpdate =
            invocation.positionalArguments.first as Map<Object, Object?>;
      });

      await sessionService.cancelSetup(
        sessionId: kPairedSessionId,
        byUserId: kPairedHostId,
        reason: 'setup_host_cancelled',
      );

      expect(capturedUpdate, isNotNull);
      final update = capturedUpdate!;
      expect(update['status'], equals('cancelled'));
      expect(update['cancelledBy'], equals(kPairedHostId));
      expect(update['cancelReason'], equals('setup_host_cancelled'));
      expect(update.containsKey('endedAt'), isTrue);

      // Must NOT touch roster or phase fields
      expect(update.containsKey('participants'), isFalse);
      expect(update.containsKey('participantTypes'), isFalse);
      expect(update.containsKey('invitationStatus'), isFalse);
      expect(update.containsKey('phase'), isFalse);
    });
  });
}
