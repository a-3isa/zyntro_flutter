import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Release uses production aps-environment; Debug stays development (Z-IOS-001)', () {
    final debug = File('ios/Runner/Runner.entitlements').readAsStringSync();
    expect(debug, contains('<string>development</string>'));
    expect(debug, isNot(contains('<string>production</string>')));

    final release = File('ios/Runner/RunnerRelease.entitlements').readAsStringSync();
    expect(release, contains('<string>production</string>'));
    expect(release, isNot(contains('<string>development</string>')));

    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(pbx, contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'));
    expect(
      pbx,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease.entitlements;'),
    );
    // Release + Profile must point at production entitlements.
    final releaseBlock = pbx.split('97C147071CF9000F007C117D /* Release */')[1]
        .split('name = Release;')[0];
    expect(
      releaseBlock,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease.entitlements;'),
    );
  });
}
