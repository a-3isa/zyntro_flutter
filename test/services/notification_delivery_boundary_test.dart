import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'notification service delivers push through the backend HTTPS endpoint',
    () {
      final source = File(
        'lib/services/notification_service.dart',
      ).readAsStringSync();

      expect(source, isNot(contains("collection('pushQueue')")));
      expect(source, contains("package:http/http.dart"));
      expect(source, contains("deliverNotificationPush"));
      expect(source, contains("'Authorization': 'Bearer \$idToken'"));
      expect(source, contains("FirebaseAppCheck.instance.getToken(false)"));
      expect(source, contains("'X-Firebase-AppCheck': appCheckToken"));
      expect(source, contains('Future<void> notifyNewFollower'));
      expect(source, contains('NotificationType.newFollower'));
    },
  );

  test(
    'joint-post invite is sent through the same CF-authoritative push path',
    () {
      final source = File(
        'lib/services/notification_service.dart',
      ).readAsStringSync();

      expect(source, contains('Future<void> sendJointPostInvite'));
      expect(source, contains('required String recipientId'));
      expect(source, contains('required String fromName'));
      expect(source, contains('required String postId'));
      expect(source, contains('required String sessionId'));
      expect(source, contains('NotificationType.jointPostInvite'));
      // No client-side doc write for the recipient — owner-only rule means
      // only the Cloud Function (via _deliverPushNotification) can persist
      // a cross-user notification.
      expect(source, contains('_deliverPushNotification('));
    },
  );
}
