import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('data inventory covers SDKs declared in PrivacyInfo (Z-PRV-001)', () {
    final inventory = File('docs/DATA_INVENTORY.md').readAsStringSync();
    final privacyInfo =
        File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    final policy = File('docs/privacy-policy.md').readAsStringSync();

    for (final needle in [
      'Firebase Analytics',
      'Firebase Crashlytics',
      'Firebase Messaging',
      'Email address',
      'Photos / images',
      'Audio data',
      'PrivacyInfo',
    ]) {
      expect(inventory, contains(needle), reason: 'missing $needle');
    }

    expect(privacyInfo, contains('NSPrivacyCollectedDataTypeEmailAddress'));
    expect(privacyInfo, contains('NSPrivacyCollectedDataTypePhotosorVideos'));
    expect(privacyInfo, contains('NSPrivacyCollectedDataTypeAudioData'));
    expect(privacyInfo, contains('NSPrivacyCollectedDataTypeCrashData'));
    expect(privacyInfo, contains('NSPrivacyCollectedDataTypeProductInteraction'));

    expect(policy, contains('DATA_INVENTORY.md'));
  });
}
