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

  test('functions never use the Dart Firestore API on a snapshot', () {
    final source = File('functions/index.js').readAsStringSync();

    // R16: expireStalePairedInvites called batch.update(doc.reference, ...).
    // `reference` is the Dart/Flutter property; the Node SDK exposes `ref` and
    // has no `reference` at all, so this passed undefined to batch.update and
    // the function threw on every scheduled run for as long as it existed —
    // paired-session invites were never expired in production.
    //
    // The failure was invisible in the stack trace: the v2 scheduler logs
    // err.message as a string, and the logger wraps a bare string in a fresh
    // Error to get a stack, so every frame pointed at the logger rather than
    // at the real call site.
    expect(
      source,
      isNot(contains('.reference')),
      reason: 'use doc.ref — .reference is the Dart API and is undefined here',
    );

    // The sibling Dart-only names, for the same reason.
    for (final dartism in ['.documents', '.getDocuments(', '.setData(', '.updateData(']) {
      expect(source, isNot(contains(dartism)), reason: dartism);
    }
  });

  test(
    'expireStaleJointPostDrafts batches its writes and fans out notifications',
    () {
      final source = File('functions/index.js').readAsStringSync();

      final start = source.indexOf('exports.expireStaleJointPostDrafts');
      expect(start, isNonNegative);
      final body = source.substring(
        start,
        source.indexOf('exports.', start + 10),
      );

      // The query is capped at 400 documents. Updating them one await at a
      // time, plus one await per confirmed author, meant hundreds of
      // sequential round trips in a single invocation — enough to risk the
      // function timeout and push expiry past its 15-minute schedule.
      expect(body, contains('db.batch()'));
      expect(body, contains('batch.commit()'));
      expect(
        body,
        isNot(contains('await doc.ref.update(')),
        reason: 'per-document awaits defeat the batch',
      );

      // allSettled, not all: one failed push must not abandon the remaining
      // authors' notifications.
      expect(body, contains('Promise.allSettled('));
      expect(body, isNot(contains('Promise.all(')));

      // A dropped notification must still be visible in the logs.
      expect(body, contains('logger.error('));
    },
  );
}
