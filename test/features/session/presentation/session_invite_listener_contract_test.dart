import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main shell mounts an expiring foreground session invite listener', () {
    final shell = File(
      'lib/features/main/presentation/main_shell.dart',
    ).readAsStringSync();
    final listener = File(
      'lib/features/session/presentation/session_invite_listener.dart',
    ).readAsStringSync();

    expect(shell, contains('SessionInviteListener'));
    expect(listener, contains('userNotificationsProvider'));
    expect(listener, contains('NotificationType.sessionInvite'));
    expect(listener, contains('expiresAt'));
    expect(listener, contains("'Decline'"));
    expect(listener, contains("'Accept'"));
    expect(listener, contains('AppRouteLocations.sessionAccept'));
  });
}
