import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS drops background fetch; sets notification presentation (Z-IOS-006)', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<string>remote-notification</string>'));
    expect(plist, isNot(contains('<string>fetch</string>')));

    final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(delegate, contains('UNUserNotificationCenter.current().delegate'));
    expect(delegate, contains('Z-IOS-006'));
  });
}
