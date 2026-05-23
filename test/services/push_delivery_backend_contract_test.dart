import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'functions backend exports authenticated HTTPS push delivery with FCM multicast',
    () {
      final source = File('functions/index.js').readAsStringSync();

      expect(source, contains('onRequest'));
      expect(source, contains('deliverNotificationPush'));
      expect(source, contains('verifyIdToken'));
      expect(source, contains('verifyToken'));
      expect(source, contains('X-Firebase-AppCheck'));
      expect(source, contains('sendEachForMulticast'));
    },
  );
}
