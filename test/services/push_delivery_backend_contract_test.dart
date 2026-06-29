import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'functions backend exports authenticated HTTPS push delivery with FCM multicast',
    () {
      final source = File('functions/index.js').readAsStringSync();

      expect(source, contains('firebase-admin/app'));
      expect(source, contains('firebase-admin/firestore'));
      expect(source, contains('firebase-admin/messaging'));
      expect(source, contains('firebase-admin/auth'));
      expect(source, contains('firebase-admin/app-check'));
      expect(source, isNot(contains('require("firebase-admin")')));
      expect(source, isNot(contains('admin.')));
      expect(source, contains('onRequest'));
      expect(source, contains('deliverNotificationPush'));
      expect(source, contains('verifyIdToken'));
      expect(source, contains('verifyToken'));
      expect(source, contains('X-Firebase-AppCheck'));
      expect(source, contains('invoker: "public"'));
      expect(source, contains('setCorsHeaders(req, res)'));
      expect(source, isNot(contains('Access-Control-Allow-Origin", "*"')));
      expect(source, contains('sendEachForMulticast'));
      expect(source, contains('case "new_follower"'));
      expect(source, contains('persistRecipientNotification'));
      expect(source, contains('.collection("notifications")'));
      expect(source, contains('notificationId'));
    },
  );
}
