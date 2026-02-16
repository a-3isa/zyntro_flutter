import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyntro_flutter/services/follow_service.dart';

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

class MockRef extends Mock implements Ref {}

void main() {
  late FollowService followService;
  late MockFirebaseFirestore mockFirestore;
  late MockRef mockRef;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockRef = MockRef();
    followService = FollowService(mockFirestore, mockRef);
  });

  test('getFollowingIds returns list of ids', () async {
    final mockCollection = MockCollectionReference();
    final mockQuery1 = MockQuery();
    final mockQuery2 = MockQuery();
    final mockSnapshot = MockQuerySnapshot();
    final mockDoc = MockQueryDocumentSnapshot();

    when(() => mockFirestore.collection('follows')).thenReturn(mockCollection);
    when(
      () => mockCollection.where('followerId', isEqualTo: 'user1'),
    ).thenReturn(mockQuery1);
    when(
      () => mockQuery1.where('status', isEqualTo: 'approved'),
    ).thenReturn(mockQuery2);
    when(() => mockQuery2.get()).thenAnswer((_) async => mockSnapshot);
    when(() => mockSnapshot.docs).thenReturn([mockDoc]);
    when(() => mockDoc.data()).thenReturn({'followeeId': 'user2'});

    final result = await followService.getFollowingIds('user1');

    expect(result, ['user2']);
  });
}
