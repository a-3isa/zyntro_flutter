import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('session invite delivery contract', () {
    test('requires mutual follow and block checks before real friend invites', () {
      final followService = File('lib/services/follow_service.dart').readAsStringSync();
      final sessionService = File('lib/services/session_service.dart').readAsStringSync();

      expect(followService, contains('canInviteToPairedSession'));
      expect(followService, contains('getFollowStatus(hostId, inviteeId)'));
      expect(followService, contains('getFollowStatus(inviteeId, hostId)'));
      expect(followService, contains("collection('blocks')"));
      expect(sessionService, contains('canInviteToPairedSession'));
    });
  });
}
