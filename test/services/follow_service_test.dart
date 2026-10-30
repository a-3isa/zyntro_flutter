import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyntro_flutter/services/follow_service.dart';
import 'dart:io';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

final _testRefProvider = Provider<Ref>((ref) => ref);

void main() {
  test('public follows dispatch new follower notifications', () {
    final source = File('lib/services/follow_service.dart').readAsStringSync();

    expect(source, contains('.notifyNewFollower('));
    expect(source, isNot(contains("I'll leave it as is")));
  });

  // Z-SEC-001 closed the users list to non-private profiles, so a whereIn
  // query over arbitrary ids would be denied; lookups are chunked doc gets.
  // Z-DATA-005 raised the chunk size to 30.
  test('follower list lookups use chunked per-document reads', () {
    final source = File('lib/services/follow_service.dart').readAsStringSync();

    expect(source, contains('static const _userLookupChunkSize = 30'));
    expect(source, contains("collection('users').doc(id).get()"));
    expect(
      source,
      isNot(contains('where(FieldPath.documentId, whereIn: chunk)')),
    );
  });

  late FollowService followService;
  late MockFirebaseFirestore mockFirestore;
  late Ref testRef;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    testRef = container.read(_testRefProvider);
    followService = FollowService(mockFirestore, testRef);
  });

  test('getFollowingIds returns list of ids', () async {
    final mockCollection = MockCollectionReference();
    final mockQuery1 = MockQuery();
    final mockQuery2 = MockQuery();
    final mockQuery3 = MockQuery();
    final mockSnapshot = MockQuerySnapshot();
    final mockDoc = MockQueryDocumentSnapshot();

    when(() => mockFirestore.collection('follows')).thenReturn(mockCollection);
    when(
      () => mockCollection.where('followerId', isEqualTo: 'user1'),
    ).thenReturn(mockQuery1);
    when(
      () => mockQuery1.where('status', isEqualTo: 'approved'),
    ).thenReturn(mockQuery2);
    // The query is now capped so a huge following list cannot be read whole.
    when(
      () => mockQuery2.limit(FollowService.followingIdsLimit),
    ).thenReturn(mockQuery3);
    when(() => mockQuery3.get()).thenAnswer((_) async => mockSnapshot);
    when(() => mockSnapshot.docs).thenReturn([mockDoc]);
    when(() => mockDoc.data()).thenReturn({'followeeId': 'user2'});

    final result = await followService.getFollowingIds('user1');

    expect(result, ['user2']);
  });

  test(
    'paired invite eligibility requires mutual follows and no blocks',
    () async {
      final followsCollection = MockCollectionReference();
      final blocksCollection = MockCollectionReference();
      final hostFollowsFriend = MockDocumentReference();
      final friendFollowsHost = MockDocumentReference();
      final hostBlocksFriend = MockDocumentReference();
      final friendBlocksHost = MockDocumentReference();
      final approvedFollow = MockDocumentSnapshot();
      final missingBlock = MockDocumentSnapshot();

      when(
        () => mockFirestore.collection('follows'),
      ).thenReturn(followsCollection);
      when(
        () => mockFirestore.collection('blocks'),
      ).thenReturn(blocksCollection);
      when(
        () => followsCollection.doc('host_friend'),
      ).thenReturn(hostFollowsFriend);
      when(
        () => followsCollection.doc('friend_host'),
      ).thenReturn(friendFollowsHost);
      when(
        () => blocksCollection.doc('host_friend'),
      ).thenReturn(hostBlocksFriend);
      when(
        () => blocksCollection.doc('friend_host'),
      ).thenReturn(friendBlocksHost);
      when(
        () => hostFollowsFriend.get(),
      ).thenAnswer((_) async => approvedFollow);
      when(
        () => friendFollowsHost.get(),
      ).thenAnswer((_) async => approvedFollow);
      when(() => hostBlocksFriend.get()).thenAnswer((_) async => missingBlock);
      when(() => friendBlocksHost.get()).thenAnswer((_) async => missingBlock);
      when(() => approvedFollow.exists).thenReturn(true);
      when(() => approvedFollow.data()).thenReturn({'status': 'approved'});
      when(() => missingBlock.exists).thenReturn(false);

      final result = await followService.canInviteToPairedSession(
        hostId: 'host',
        inviteeId: 'friend',
      );

      expect(result, isTrue);
    },
  );
}
