// test/services/session_lobby_gate_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/services/session_lobby_gate.dart';

void main() {
  group('requiredRoster', () {
    test('is host plus invited, de-duplicated', () {
      expect(
        requiredRoster(hostId: 'h', invitedUserIds: ['f', 'h']),
        ['h', 'f'],
      );
    });
  });

  group('shouldGoLive', () {
    const roster = ['h', 'f'];

    test('false when invited friend has not joined yet', () {
      expect(
        shouldGoLive(
          requiredRoster: roster,
          participants: ['h'],
          planReadiness: {'h': true},
          invitationStatus: 'accepted',
        ),
        isFalse,
      );
    });

    test('false when a required member is not ready', () {
      expect(
        shouldGoLive(
          requiredRoster: roster,
          participants: ['h', 'f'],
          planReadiness: {'h': true, 'f': false},
          invitationStatus: 'accepted',
        ),
        isFalse,
      );
    });

    test('false while the invitation is still pending', () {
      expect(
        shouldGoLive(
          requiredRoster: roster,
          participants: ['h', 'f'],
          planReadiness: {'h': true, 'f': true},
          invitationStatus: 'pending',
        ),
        isFalse,
      );
    });

    test('true when roster joined, all ready, invite accepted', () {
      expect(
        shouldGoLive(
          requiredRoster: roster,
          participants: ['h', 'f'],
          planReadiness: {'h': true, 'f': true},
          invitationStatus: 'accepted',
        ),
        isTrue,
      );
    });

    test('true for solo-style roster (no invite) when host ready', () {
      expect(
        shouldGoLive(
          requiredRoster: ['h'],
          participants: ['h'],
          planReadiness: {'h': true},
          invitationStatus: null,
        ),
        isTrue,
      );
    });

    test('matchmaking: false when a non-roster participant is not ready', () {
      // Matchmaking adds the partner via joinSession, so roster == [host] but
      // participants == [host, partner]. The partner must still be ready.
      expect(
        shouldGoLive(
          requiredRoster: ['h'],
          participants: ['h', 'p'],
          planReadiness: {'h': true, 'p': false},
          invitationStatus: null,
        ),
        isFalse,
      );
    });

    test('matchmaking: true when all participants ready (roster not naming partner)', () {
      expect(
        shouldGoLive(
          requiredRoster: ['h'],
          participants: ['h', 'p'],
          planReadiness: {'h': true, 'p': true},
          invitationStatus: null,
        ),
        isTrue,
      );
    });
  });
}
