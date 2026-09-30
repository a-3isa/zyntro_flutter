import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/services/moderation_service.dart';

final _testRefProvider = Provider<Ref>((ref) => ref);

void main() {
  late FakeFirebaseFirestore firestore;
  late ModerationService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    service = ModerationService(firestore, container.read(_testRefProvider));
  });

  test('blockDocId is deterministic for blocker/blocked pair', () {
    expect(
      ModerationService.blockDocId('alice', 'bob'),
      'alice_bob',
    );
  });

  test('blockUser writes block doc and getBlockedUserIds returns it (Z-TEST-002)',
      () async {
    await service.blockUser('alice', 'bob');

    final doc = await firestore.collection('blocks').doc('alice_bob').get();
    expect(doc.exists, isTrue);
    expect(doc.data()?['blockerId'], 'alice');
    expect(doc.data()?['blockedUserId'], 'bob');

    final ids = await service.getBlockedUserIds('alice');
    expect(ids, contains('bob'));
    expect(await service.isUserBlocked('alice', 'bob'), isTrue);
  });

  test('unblockUser removes the block document', () async {
    await service.blockUser('alice', 'bob');
    await service.unblockUser('alice', 'bob');

    final doc = await firestore.collection('blocks').doc('alice_bob').get();
    expect(doc.exists, isFalse);
    expect(await service.getBlockedUserIds('alice'), isEmpty);
    expect(await service.isUserBlocked('alice', 'bob'), isFalse);
  });
}
