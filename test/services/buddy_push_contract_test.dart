import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CF buildPushPayload supports buddy types (Z-NOTIF-001)', () {
    final source = File('functions/index.js').readAsStringSync();
    expect(source, contains('case "buddy_invite":'));
    expect(source, contains('case "buddy_accepted":'));
    expect(source, contains('case "buddy_session":'));
    expect(source, contains('buildBuddyInvitePayload'));
    expect(source, contains('enabled("buddyInvites")'));
  });

  test('client buddy notify paths are CF-only (no inbox create)', () {
    final source = File(
      'lib/services/notification_service.dart',
    ).readAsStringSync();
    final inviteIdx = source.indexOf('Future<void> notifyBuddyInvite');
    final acceptedIdx = source.indexOf('Future<void> notifyBuddyAccepted');
    final sessionIdx = source.indexOf('Future<void> notifyBuddySession');
    expect(inviteIdx, isNonNegative);
    final inviteBody = source.substring(inviteIdx, acceptedIdx);
    final acceptedBody = source.substring(acceptedIdx, sessionIdx);
    final sessionBody = source.substring(sessionIdx, sessionIdx + 500);
    expect(inviteBody, contains('_deliverPushNotification'));
    expect(inviteBody, isNot(contains('createNotification')));
    expect(acceptedBody, isNot(contains('createNotification')));
    expect(sessionBody, isNot(contains('createNotification')));
  });
}
