import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release signingConfig is gated on key.properties (Z-AND-003)', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('if (keystorePropertiesFile.exists())'));
    // Must not unconditionally assign the release signing config.
    expect(
      gradle,
      isNot(
        contains(
          RegExp(
            r'release \{\s*signingConfig = signingConfigs\.getByName\("release"\)',
          ),
        ),
      ),
    );
    expect(
      gradle,
      contains('signingConfig = signingConfigs.getByName("release")'),
    );
  });
}
