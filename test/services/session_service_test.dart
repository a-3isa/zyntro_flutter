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
import 'package:zyntro_flutter/services/buddy_review_prompt_service.dart';

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

final _testRefProvider = Provider<Ref>((ref) => ref);

class MockUserCacheService extends Mock implements UserCacheService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockSessionAnalyticsService extends Mock
    implements SessionAnalyticsService {}

class MockFollowService extends Mock implements FollowService {}

class MockBuddyReviewPromptService extends Mock
    implements BuddyReviewPromptService {}

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
  String? partnerKind,
  String? invitationStatus,
}) {
  final resolvedParticipants = participants ?? [hostId, partnerId];
  return {
    'hostId': hostId,
    'partnerId': partnerId,
    'title': 'Paired Workout',
    'type': type,
    'status': status,
    'partnerKind': ?partnerKind,
    'invitationStatus': ?invitationStatus,
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
  late Ref testRef;
  late MockUserCacheService mockUserCacheService;
  late MockNotificationService mockNotificationService;
  late MockSessionAnalyticsService mockSessionAnalyticsService;
  late MockFollowService mockFollowService;
  late MockBuddyReviewPromptService mockBuddyReviewPromptService;
  late MockCollectionReference mockSessionsCollection;
  late MockDocumentReference mockSessionDoc;
  late MockBatch mockBatch;
  late MockCollectionReference mockUsersCollection;
  late MockDocumentReference mockUserDoc;
  late MockCollectionReference mockUserStatsCollection;
  late MockDocumentReference mockUserPrsDoc;
  late MockDocumentSnapshot mockUserPrsSnapshot;

  setUpAll(() {
    registerFallbackValue(FakeDocumentReferenceObject());
    registerFallbackValue(FakeDocumentReferenceMap());
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockUserCacheService = MockUserCacheService();
    mockNotificationService = MockNotificationService();
    mockSessionAnalyticsService = MockSessionAnalyticsService();
    mockFollowService = MockFollowService();
    mockBuddyReviewPromptService = MockBuddyReviewPromptService();
    mockSessionsCollection = MockCollectionReference();
    mockSessionDoc = MockDocumentReference();
    mockBatch = MockBatch();
    mockUsersCollection = MockCollectionReference();
    mockUserDoc = MockDocumentReference();
    mockUserStatsCollection = MockCollectionReference();
    mockUserPrsDoc = MockDocumentReference();
    mockUserPrsSnapshot = MockDocumentSnapshot();

    when(
      () => mockBuddyReviewPromptService.onBuddySessionCompleted(),
    ).thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        userCacheServiceProvider.overrideWithValue(mockUserCacheService),
        notificationServiceProvider.overrideWithValue(mockNotificationService),
        sessionAnalyticsServiceProvider.overrideWithValue(
          mockSessionAnalyticsService,
        ),
        followServiceProvider.overrideWithValue(mockFollowService),
        buddyReviewPromptServiceProvider.overrideWithValue(
          mockBuddyReviewPromptService,
        ),
      ],
    );
    addTearDown(container.dispose);
    testRef = container.read(_testRefProvider);

    // Setup Firestore
    when(() => mockFirestore.collection(any())).thenAnswer((invocation) {
      final name = invocation.positionalArguments.first as String;
      return name == 'users' ? mockUsersCollection : mockSessionsCollection;
    });
    when(() => mockFirestore.batch()).thenReturn(mockBatch);
    when(() => mockSessionsCollection.doc(any())).thenReturn(mockSessionDoc);
    when(
      () => mockSessionDoc.collection(any()),
    ).thenReturn(mockSessionsCollection); // Simplified
    when(() => mockSessionDoc.update(any())).thenAnswer((_) async {});
    when(() => mockSessionDoc.set(any())).thenAnswer((_) async {});
    when(() => mockBatch.commit()).thenAnswer((_) async {});

    when(() => mockUsersCollection.doc(any())).thenReturn(mockUserDoc);
    when(
      () => mockUserDoc.collection('stats'),
    ).thenReturn(mockUserStatsCollection);
    when(
      () => mockUserStatsCollection.doc('prs'),
    ).thenReturn(mockUserPrsDoc);
    when(() => mockUserPrsDoc.get()).thenAnswer((_) async => mockUserPrsSnapshot);
    when(() => mockUserPrsSnapshot.exists).thenReturn(false);
    when(() => mockUserPrsSnapshot.data()).thenReturn(null);
    when(() => mockUserDoc.update(any())).thenAnswer((_) async {});
    when(() => mockBatch.set(any(), any(), any())).thenAnswer((_) async {});

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

    sessionService = SessionService(mockFirestore, testRef);
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

    test('matching gym is turn-based; same-type cardio and mixed are parallel', () {
      expect(
        SessionService.derivePairedSessionMode(const {
          'host': 'gym',
          'friend': 'gym',
        }),
        SessionMode.turnBased,
      );
      expect(
        SessionService.derivePairedSessionMode(const {
          'host': 'running',
          'friend': 'running',
        }),
        SessionMode.parallel,
      );
      expect(
        SessionService.derivePairedSessionMode(const {
          'host': 'gym',
          'friend': 'running',
        }),
        SessionMode.parallel,
      );
      expect(
        Session.modeFromParticipantTypes(const {
          'host': 'running',
          'friend': 'running',
        }),
        SessionService.derivePairedSessionMode(const {
          'host': 'running',
          'friend': 'running',
        }),
      );
    });

    test('sharedClockStartFields omit mode and do not start the clock', () {
      final fields = SessionService.sharedClockStartFields(
        participantTypes: const {
          kPairedHostId: 'gym',
          kPairedFriendId: 'running',
        },
      );

      expect(fields.containsKey('mode'), isFalse);
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
      expect(sessionData.containsKey('mode'), isFalse);
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
      ).captured.map((value) {
        return Map<String, dynamic>.from(value as Map);
      }).toList();

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

    test('switchTurn updates activeUserId via transaction', () async {
      // Covered by FakeFirestore suite in switch_turn_transaction_test.dart
      // (Z-RT-002). Mocktail cannot reliably stub runTransaction generics here.
      expect(true, isTrue);
    }, skip: 'see switch_turn_transaction_test.dart');

    test('endSession does not persist caller score or partner user docs', () async {
      final mockDocSnapshot = MockDocumentSnapshot();
      when(() => mockSessionDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(true);
      when(() => mockDocSnapshot.id).thenReturn(kPairedSessionId);
      when(() => mockDocSnapshot.data()).thenReturn(buildPairedSessionData());

      await sessionService.endSession(kPairedSessionId, kPairedHostId, null);

      // PRs doc ref + streak read only — no third write ref (Z-DATA-001).
      verify(() => mockUsersCollection.doc(kPairedHostId)).called(2);
      verifyNever(() => mockUsersCollection.doc(kPairedFriendId));
      verifyNever(() => mockBatch.update(mockUserDoc, any()));
      verify(() => mockBatch.commit()).called(1);
    });

    test('endSession scores a solo strength session with no prior PRs', () async {
      final mockDocSnapshot = MockDocumentSnapshot();
      when(() => mockSessionDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(true);
      when(() => mockDocSnapshot.id).thenReturn(kPairedSessionId);
      when(() => mockDocSnapshot.data()).thenReturn({
        ...buildPairedSessionData(),
        'type': 'strength',
        'startedAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 20))),
      });

      final summary = SessionSummary(
        totalSets: 3,
        exercises: [
          ExerciseSummary(
            name: 'Bench Press',
            sets: 3,
            setDetails: [
              SetSummary(reps: 8, weight: 50, durationSeconds: 0),
              SetSummary(reps: 8, weight: 50, durationSeconds: 0),
              SetSummary(reps: 8, weight: 50, durationSeconds: 0),
            ],
          ),
        ],
      );

      final localScore = await sessionService.endSession(
        kPairedSessionId,
        kPairedHostId,
        summary,
      );

      // 20 min time + 0 buddy (bot/solo) + 6 effort (3 sets * 2) + 40 progress
      // (first-time 5% * 800) = 66. Returned for recap; not persisted (Z-DATA-001).
      expect(localScore, 66);
      verifyNever(() => mockBatch.update(mockUserDoc, any()));
      verifyNever(
        () => mockBatch.set<Map<String, dynamic>>(mockUserPrsDoc, any(), any()),
      );
    });

    test(
      'endSession scores a realistic gym session — session.type is a '
      'WorkoutType value, not a scorer category literal',
      () async {
        // Regression guard: `session.type` is always a WorkoutType.value
        // ('gym', 'running', ...). Passing it straight to computeWorkoutScore
        // (which branches on the categories 'strength'/'cardio') made effort and
        // progress silently zero for every real session in production.
        final mockDocSnapshot = MockDocumentSnapshot();
        when(
          () => mockSessionDoc.get(),
        ).thenAnswer((_) async => mockDocSnapshot);
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn(kPairedSessionId);
        when(() => mockDocSnapshot.data()).thenReturn({
          ...buildPairedSessionData(type: WorkoutType.gym.value),
          'startedAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 20)),
          ),
        });

        final summary = SessionSummary(
          totalSets: 3,
          exercises: [
            ExerciseSummary(
              name: 'Bench Press',
              sets: 3,
              setDetails: [
                SetSummary(reps: 8, weight: 50, durationSeconds: 0),
                SetSummary(reps: 8, weight: 50, durationSeconds: 0),
                SetSummary(reps: 8, weight: 50, durationSeconds: 0),
              ],
            ),
          ],
        );

        final localScore = await sessionService.endSession(
          kPairedSessionId,
          kPairedHostId,
          summary,
        );

        // 20 time + 0 buddy + 6 effort (3 sets * 2) + 40 progress (first-time
        // 5% * 800) = 66. The effort+progress contribution (46) is exactly what
        // the type-matching bug silently dropped — a time-only score of 20 here
        // means the scorer fell through both branches again.
        expect(localScore, 66);
        expect(localScore, isNot(20));
        verifyNever(() => mockBatch.update(mockUserDoc, any()));
        verifyNever(
          () =>
              mockBatch.set<Map<String, dynamic>>(mockUserPrsDoc, any(), any()),
        );
      },
    );

    test(
      'endSession scores a realistic running session as cardio',
      () async {
        final mockDocSnapshot = MockDocumentSnapshot();
        when(
          () => mockSessionDoc.get(),
        ).thenAnswer((_) async => mockDocSnapshot);
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn(kPairedSessionId);
        when(() => mockDocSnapshot.data()).thenReturn({
          ...buildPairedSessionData(type: WorkoutType.running.value),
          'startedAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 20)),
          ),
        });

        final localScore = await sessionService.endSession(
          kPairedSessionId,
          kPairedHostId,
          SessionSummary(activityType: 'running', averageSpeed: 11.0),
        );

        // 20 time + 0 effort (cardio) + 40 progress (first-time 5% * 800) = 60.
        expect(localScore, 60);
        verifyNever(() => mockBatch.update(mockUserDoc, any()));
      },
    );

    test(
      'endSession scores a yoga session as flexibility — time and buddy only',
      () async {
        final mockDocSnapshot = MockDocumentSnapshot();
        when(
          () => mockSessionDoc.get(),
        ).thenAnswer((_) async => mockDocSnapshot);
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn(kPairedSessionId);
        when(() => mockDocSnapshot.data()).thenReturn({
          ...buildPairedSessionData(type: WorkoutType.yoga.value),
          'startedAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 20)),
          ),
        });

        final localScore = await sessionService.endSession(
          kPairedSessionId,
          kPairedHostId,
          SessionSummary(totalSets: 5),
        );

        // By design: flexibility scores time only (no effort, no progress).
        expect(localScore, 20);
        verifyNever(() => mockBatch.update(mockUserDoc, any()));
        verifyNever(
          () =>
              mockBatch.set<Map<String, dynamic>>(mockUserPrsDoc, any(), any()),
        );
      },
    );

    group('endSession buddy bonus', () {
      Future<int> scoreForInvite({
        required String partnerKind,
        String? invitationStatus,
      }) async {
        final mockDocSnapshot = MockDocumentSnapshot();
        when(
          () => mockSessionDoc.get(),
        ).thenAnswer((_) async => mockDocSnapshot);
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn(kPairedSessionId);
        when(() => mockDocSnapshot.data()).thenReturn({
          ...buildPairedSessionData(
            type: WorkoutType.yoga.value, // time + buddy only, easy to read
            partnerKind: partnerKind,
            invitationStatus: invitationStatus,
          ),
          'startedAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 20)),
          ),
        });

        return sessionService.endSession(
          kPairedSessionId,
          kPairedHostId,
          null,
        );
      }

      test('an accepted real-friend invite earns the +15 bonus', () async {
        // 20 time + 15 buddy.
        expect(
          await scoreForInvite(
            partnerKind: PairedPartnerKind.realFriend.value,
            invitationStatus: WorkoutInvitationStatus.accepted.value,
          ),
          35,
        );
      });

      test('a pending invite earns no buddy bonus', () async {
        // partnerKind is stamped at creation; the friend never showed up.
        expect(
          await scoreForInvite(
            partnerKind: PairedPartnerKind.realFriend.value,
            invitationStatus: WorkoutInvitationStatus.pending.value,
          ),
          20,
        );
      });

      test('a declined invite earns no buddy bonus', () async {
        expect(
          await scoreForInvite(
            partnerKind: PairedPartnerKind.realFriend.value,
            invitationStatus: WorkoutInvitationStatus.declined.value,
          ),
          20,
        );
      });

      test('an expired or cancelled invite earns no buddy bonus', () async {
        expect(
          await scoreForInvite(
            partnerKind: PairedPartnerKind.realFriend.value,
            invitationStatus: WorkoutInvitationStatus.expired.value,
          ),
          20,
        );
        expect(
          await scoreForInvite(
            partnerKind: PairedPartnerKind.realFriend.value,
            invitationStatus: WorkoutInvitationStatus.cancelled.value,
          ),
          20,
        );
      });

      test('a missing invitationStatus earns no buddy bonus', () async {
        expect(
          await scoreForInvite(
            partnerKind: PairedPartnerKind.realFriend.value,
          ),
          20,
        );
      });

      test('a bot partner earns no buddy bonus even if accepted', () async {
        expect(
          await scoreForInvite(
            partnerKind: PairedPartnerKind.bot.value,
            invitationStatus: WorkoutInvitationStatus.accepted.value,
          ),
          20,
        );
      });
    });

    test('parsePersonalBests reads a well-formed stats/prs section', () {
      final parsed = SessionService.parsePersonalBests({
        'bench press': {
          'bestEstimate': 66.6,
          'achievedAt': null,
          'sourceSessionId': 's1',
        },
        'squat': {'bestEstimate': 100},
      });

      expect(parsed, {'bench press': 66.6, 'squat': 100.0});
    });

    test(
      'parsePersonalBests never throws on a malformed stats/prs doc',
      () {
        // Firestore rules let a client write any shape to its own stats/prs
        // doc. An unguarded cast here runs before the batch is built, so a
        // throw would permanently block endSession for that user.
        expect(SessionService.parsePersonalBests(null), isEmpty);
        expect(SessionService.parsePersonalBests('not-a-map'), isEmpty);
        expect(SessionService.parsePersonalBests(42), isEmpty);
        expect(SessionService.parsePersonalBests(const []), isEmpty);

        // Entry-level garbage skips just that entry, keeping the good ones.
        final mixed = SessionService.parsePersonalBests({
          'legacy-shape': 120, // old maxWeight number, not a map
          'no-best-estimate': {'achievedAt': 'yesterday'},
          'string-best-estimate': {'bestEstimate': '80'},
          'null-best-estimate': {'bestEstimate': null},
          'nan-best-estimate': {'bestEstimate': double.nan},
          'infinite-best-estimate': {'bestEstimate': double.infinity},
          7: {'bestEstimate': 90}, // non-string key
          'good': {'bestEstimate': 55.5},
        });
        expect(mixed, {'good': 55.5});
      },
    );

    test(
      'endSession still completes when the stats/prs doc is malformed',
      () async {
        final mockDocSnapshot = MockDocumentSnapshot();
        when(
          () => mockSessionDoc.get(),
        ).thenAnswer((_) async => mockDocSnapshot);
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn(kPairedSessionId);
        when(() => mockDocSnapshot.data()).thenReturn({
          ...buildPairedSessionData(type: WorkoutType.gym.value),
          'startedAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 20)),
          ),
        });

        // Old/foreign shape: `strength` is a bare number map, `cardio` a string.
        when(() => mockUserPrsSnapshot.exists).thenReturn(true);
        when(() => mockUserPrsSnapshot.data()).thenReturn({
          'strength': {'bench press': 120},
          'cardio': 'corrupted',
        });

        await sessionService.endSession(
          kPairedSessionId,
          kPairedHostId,
          SessionSummary(
            totalSets: 3,
            exercises: [
              ExerciseSummary(
                name: 'Bench Press',
                sets: 3,
                setDetails: [
                  SetSummary(reps: 8, weight: 50, durationSeconds: 0),
                ],
              ),
            ],
          ),
        );

        // Did not throw; the session still completed without persisting score.
        verify(() => mockBatch.commit()).called(1);
        verifyNever(() => mockBatch.update(mockUserDoc, any()));
        verifyNever(
          () =>
              mockBatch.set<Map<String, dynamic>>(mockUserPrsDoc, any(), any()),
        );
      },
    );

    test(
      'endSession survives a failed stats/prs read and suppresses the PR write',
      () async {
        final mockDocSnapshot = MockDocumentSnapshot();
        when(
          () => mockSessionDoc.get(),
        ).thenAnswer((_) async => mockDocSnapshot);
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn(kPairedSessionId);
        when(() => mockDocSnapshot.data()).thenReturn({
          ...buildPairedSessionData(type: WorkoutType.gym.value),
          'startedAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 20)),
          ),
        });

        // Offline / permission-denied read.
        when(
          () => mockUserPrsDoc.get(),
        ).thenThrow(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));

        final localScore = await sessionService.endSession(
          kPairedSessionId,
          kPairedHostId,
          SessionSummary(
            totalSets: 3,
            exercises: [
              ExerciseSummary(
                name: 'Bench Press',
                sets: 3,
                setDetails: [
                  SetSummary(reps: 8, weight: 50, durationSeconds: 0),
                ],
              ),
            ],
          ),
        );

        // The user is not blocked from finishing; score is local-only.
        verify(() => mockBatch.commit()).called(1);
        expect(localScore, 66);
        verifyNever(() => mockBatch.update(mockUserDoc, any()));
        verifyNever(
          () =>
              mockBatch.set<Map<String, dynamic>>(mockUserPrsDoc, any(), any()),
        );
      },
    );

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
