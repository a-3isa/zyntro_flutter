import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/features/session/domain/turn_eligibility.dart';
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

  // A force-killed app never gets to write `away` or `offline`, so it leaves
  // `status: 'online'` behind permanently. Trusting `status` alone would make
  // every abandoned session read as occupied — and the warm/quiet split would
  // then resolve the wrong way on exactly the sessions this feature exists to
  // catch. Hence the staleness check.
  group('isPresenceLive', () {
    final now = DateTime.utc(2026, 8, 5, 12, 0);

    UserPresence aged(PresenceStatus status, Duration age) => UserPresence(
      userId: alice,
      status: status,
      lastChanged: now.subtract(age),
    );

    test('a freshly refreshed online record counts as present', () {
      expect(
        PresenceService.isPresenceLive(
          aged(PresenceStatus.online, Duration.zero),
          now,
        ),
        isTrue,
      );
    });

    test('tolerates a missed heartbeat', () {
      // Used in gyms, where patchy reception is normal. Calling a signal drop a
      // departure would swap the member into solo mode while their partner is
      // standing next to them. Since Z-PERF-004 (30s heartbeat) the tolerance
      // comes from the presence timeout plus the solo damper's grace period:
      // a missed beat must be repaired by the next one before the view goes
      // solo.
      expect(
        PresenceService.presenceTimeout + SoloModeDamper.graceBeforeSolo,
        greaterThan(PresenceService.heartbeatInterval * 2),
        reason: 'a dropped beat must not read as leaving',
      );
      expect(
        PresenceService.isPresenceLive(
          aged(PresenceStatus.online, PresenceService.heartbeatInterval),
          now,
        ),
        isTrue,
      );
    });

    test('still notices a departure quickly', () {
      // The whole cost of a slow timeout is paid by the member who stayed, as
      // time spent looking at a partner who has actually gone.
      expect(
        PresenceService.presenceTimeout,
        lessThanOrEqualTo(const Duration(seconds: 45)),
      );
    });

    test('a stale online record does NOT count as present', () {
      // The force-killed app: still claims online, never refreshed again.
      expect(
        PresenceService.isPresenceLive(
          aged(PresenceStatus.online, const Duration(minutes: 5)),
          now,
        ),
        isFalse,
      );
    });

    test('stops counting at the timeout boundary', () {
      expect(
        PresenceService.isPresenceLive(
          aged(
            PresenceStatus.online,
            PresenceService.presenceTimeout - const Duration(seconds: 1),
          ),
          now,
        ),
        isTrue,
      );
      expect(
        PresenceService.isPresenceLive(
          aged(PresenceStatus.online, PresenceService.presenceTimeout),
          now,
        ),
        isFalse,
      );
    });

    test('away never counts as present, however fresh', () {
      expect(
        PresenceService.isPresenceLive(
          aged(PresenceStatus.away, Duration.zero),
          now,
        ),
        isFalse,
      );
    });

    test('offline never counts as present, however fresh', () {
      expect(
        PresenceService.isPresenceLive(
          aged(PresenceStatus.offline, Duration.zero),
          now,
        ),
        isFalse,
      );
    });

    test('a missing record counts as absent', () {
      expect(PresenceService.isPresenceLive(null, now), isFalse);
    });
  });

  group('startHeartbeat', () {
    test('asserts presence immediately rather than after the first interval',
        () async {
      final timer = service.startHeartbeat(sessionId, alice);
      addTearDown(timer.cancel);

      // Without the eager first beat a member who just walked in would be
      // invisible — and read as absent — for a full interval.
      await Future<void>.delayed(Duration.zero);
      expect((await readPresence(alice))?['status'], 'online');
    });

    test('pushes the session occupancy and expiry forward', () async {
      await firestore.collection('sessions').doc(sessionId).set({
        'participants': [alice],
        'status': 'active',
        'phase': 'live',
      });

      final timer = service.startHeartbeat(sessionId, alice);
      addTearDown(timer.cancel);
      await Future<void>.delayed(Duration.zero);

      final session =
          (await firestore.collection('sessions').doc(sessionId).get()).data();
      expect(session?['lastOccupiedAt'], isNotNull);
      expect(session?['expiresAt'], isNotNull);
    });

    test('refreshes occupancy less often than presence', () async {
      // Presence decides what the member sees and wants to be quick; occupancy
      // only has to keep a three-hour expiry from firing. Tying them together
      // would multiply writes to the session document for no benefit.
      expect(
        PresenceService.occupancyRefreshInterval,
        greaterThan(PresenceService.heartbeatInterval),
      );
    });

    test('does not stamp the activity clock — occupancy is not activity',
        () async {
      await firestore.collection('sessions').doc(sessionId).set({
        'participants': [alice],
        'status': 'active',
        'phase': 'live',
      });

      final timer = service.startHeartbeat(sessionId, alice);
      addTearDown(timer.cancel);
      await Future<void>.delayed(Duration.zero);

      // Sitting in the room keeps the session alive but must leave it reading
      // as quiet, or a session nobody is working in would redirect as warm.
      final session =
          (await firestore.collection('sessions').doc(sessionId).get()).data();
      expect(session?.containsKey('lastActivityAt'), isFalse);
    });
  });
}
