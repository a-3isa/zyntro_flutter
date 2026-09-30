import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS deployment target is 15.0 (Z-IOS-005)', () {
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(pbx, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0;')));
    expect(pbx, contains('IPHONEOS_DEPLOYMENT_TARGET = 15.0;'));
  });

  test('Podfile is committed and pins iOS 15 (Z-IOS-004)', () {
    final podfile = File('ios/Podfile').readAsStringSync();
    expect(podfile, contains("platform :ios, '15.0'"));
  });

  test('Info.plist declares Facebook Login keys (Z-IOS-002)', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>FacebookAppID</key>'));
    expect(plist, contains('<string>1231492372238127</string>'));
    expect(plist, contains('<string>fb1231492372238127</string>'));
    expect(plist, contains('<key>FacebookClientToken</key>'));
  });
}
