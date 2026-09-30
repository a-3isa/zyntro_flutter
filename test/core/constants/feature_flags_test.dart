import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/constants/feature_flags.dart';

void main() {
  group('FeatureFlags', () {
    test('paired friend sessions are guarded by a dedicated flag', () {
      expect(FeatureFlag.pairedFriendSessions, isA<FeatureFlag>());
      expect(FeatureFlags.isPairedFriendSessionsEnabled, isTrue);
      expect(
        FeatureFlags.isFeatureEnabled(FeatureFlag.pairedFriendSessions),
        isTrue,
      );
    });
  });
}
