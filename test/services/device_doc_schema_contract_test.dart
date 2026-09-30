import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('device docs store locale and appVersion (Z-NOTIF-003)', () {
    final source =
        File('lib/services/notification_service.dart').readAsStringSync();
    expect(source, contains("'locale': locale"));
    expect(source, contains("'appVersion': appVersion"));
    expect(source, contains('PackageInfo.fromPlatform'));
    expect(source, contains('Z-NOTIF-003'));
  });
}
