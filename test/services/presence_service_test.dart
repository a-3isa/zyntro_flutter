import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/services/presence_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late PresenceService service;
  const sessionId = 'session-1';
  const alice = 'alice';
  const bob = 'bob';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = PresenceService(firestore);
  });

  Future<Map<String, dynamic>?> readPresence(String userId) async {
    final doc = await firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('presence')
        .doc(userId)
        .get();
    return doc.data();
  }

  group('PresenceStatusExtension.fromString', () {
    test('parses each known status', () {
      expect(PresenceStatusExtension.fromString('online'), PresenceStatus.online);
      expect(PresenceStatusExtension.fromString('offline'), PresenceStatus.offline);
      expect(PresenceStatusExtension.fromString('away'), PresenceStatus.away);
    });

    test('falls back to offline for anything unrecognised', () {
      // A malformed value must read as offline rather than throwing inside a
      // stream that renders the session room.
      expect(PresenceStatusExtension.fromString('gibberish'),
          PresenceStatus.offline);
      expect(PresenceStatusExtension.fromString(''), PresenceStatus.offline);
    });
  });

  group('setting presence', () {
    test('setOnline writes the online status and the user id', () async {
      await service.setOnline(sessionId, alice);

      final data = await readPresence(alice);
      expect(data?['status'], 'online');
      expect(data?['userId'], alice);
      expect(data?['lastChanged'], isNotNull);
    });

    test('setAway and setOffline write their own statuses', () async {
      await service.setAway(sessionId, alice);
      expect((await readPresence(alice))?['status'], 'away');

      await service.setOffline(sessionId, alice);
      expect((await readPresence(alice))?['status'], 'offline');
    });

    test('presence is keyed per user, not shared', () async {
      await service.setOnline(sessionId, alice);
      await service.setOffline(sessionId, bob);

      expect((await readPresence(alice))?['status'], 'online');
      expect((await readPresence(bob))?['status'], 'offline');
    });

    test('presence is scoped to its session', () async {
      await service.setOnline(sessionId, alice);

      final other = await firestore
          .collection('sessions')
          .doc('other-session')
          .collection('presence')
          .doc(alice)
          .get();

      expect(other.exists, isFalse);
    });

    test('records the typing flag when given one', () async {
      await service.updateSessionPresence(
        sessionId,
        alice,
        PresenceStatus.online,
        isTyping: true,
      );

      expect((await readPresence(alice))?['isTyping'], isTrue);
    });

    test('omits the typing flag entirely when not given', () async {
      await service.updateSessionPresence(
        sessionId,
        alice,
        PresenceStatus.online,
      );

      expect((await readPresence(alice))?.containsKey('isTyping'), isFalse);
    });
  });

  group('getUserPresence', () {
    test('reads back what was written', () async {
      await service.setAway(sessionId, alice);

      expect(await service.getUserPresence(sessionId, alice),
          PresenceStatus.away);
    });

    test('treats an absent record as offline', () async {
      expect(await service.getUserPresence(sessionId, 'never-joined'),
          PresenceStatus.offline);
    });

    test('treats a malformed status as offline', () async {
      await firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('presence')
          .doc(alice)
          .set({'status': 42});

      expect(await service.getUserPresence(sessionId, alice),
          PresenceStatus.offline);
    });
  });

  group('getOnlineCount', () {
    test('is zero for a session nobody has joined', () async {
      expect(await service.getOnlineCount(sessionId), 0);
    });

    test('counts only the online participants', () async {
      await service.setOnline(sessionId, alice);
      await service.setAway(sessionId, bob);

      expect(await service.getOnlineCount(sessionId), 1);
    });

    test('follows a participant going offline', () async {
      await service.setOnline(sessionId, alice);
      await service.setOnline(sessionId, bob);
      expect(await service.getOnlineCount(sessionId), 2);

      await service.setOffline(sessionId, bob);
      expect(await service.getOnlineCount(sessionId), 1);
    });
  });

  group('removePresence', () {
    test('deletes the record', () async {
      await service.setOnline(sessionId, alice);

      await service.removePresence(sessionId, alice);

      expect(await readPresence(alice), isNull);
      expect(await service.getUserPresence(sessionId, alice),
          PresenceStatus.offline);
    });

    test('is safe for a user who never had a record', () async {
      await expectLater(
        service.removePresence(sessionId, 'never-joined'),
        completes,
      );
    });

    test('leaves the other participant alone', () async {
      await service.setOnline(sessionId, alice);
      await service.setOnline(sessionId, bob);

      await service.removePresence(sessionId, alice);

      expect((await readPresence(bob))?['status'], 'online');
    });
  });

  group('listenToSessionPresence', () {
    test('emits the online participants', () async {
      await service.setOnline(sessionId, alice);
      await service.setAway(sessionId, bob);

      final online = await service.listenToSessionPresence(sessionId).first;

      expect(online, [alice]);
    });

    test('emits an empty list when nobody is online', () async {
      await service.setOffline(sessionId, alice);

      expect(await service.listenToSessionPresence(sessionId).first, isEmpty);
    });
  });

  group('listenToAllPresence', () {
    test('emits every participant regardless of status', () async {
      await service.setOnline(sessionId, alice);
      await service.setOffline(sessionId, bob);

      final all = await service.listenToAllPresence(sessionId).first;

      expect(all.map((p) => p.userId), containsAll(<String>[alice, bob]));
    });
  });
}
