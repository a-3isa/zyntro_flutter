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
    },
  );
}
