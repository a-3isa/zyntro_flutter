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

  test(
    'server-initiated notifications reach devices through the shared push path',
    () {
      final source = File('functions/index.js').readAsStringSync();

      // A single shared helper owns FCM delivery, so no notification type can
      // be written to Firestore and silently never pushed.
      expect(source, contains('async function pushToRecipientDevices('));
      expect(
        'sendEachForMulticast'.allMatches(source).length,
        1,
        reason: 'FCM sending must stay in pushToRecipientDevices only',
      );

      final offerIndex = source.indexOf('async function sendSoloRepostOffer(');
      expect(offerIndex, isNonNegative);
      final offerBody = source.substring(
        offerIndex,
        source.indexOf('exports.expireStaleJointPostDrafts', offerIndex),
      );

      // The joint-draft expiry offer is scheduled (no HTTP caller), so it has
      // to invoke the push path itself rather than only writing the in-app doc.
      expect(
        offerBody,
        contains('pushToRecipientDevices(userId, "joint_post_expired", payload)'),
      );
      expect(offerBody, contains('.collection("notifications")'));

      // The stale claim that some other delivery path pushes this for us.
      expect(
        source,
        isNot(contains('Task 7 delivery path handles the push side')),
      );
    },
  );
}
