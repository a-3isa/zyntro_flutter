import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';
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
  });
}
