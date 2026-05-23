import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/app/runtime_environment_values.dart';

void main() {
  group('RuntimeEnvironmentValues', () {
    test('returns an empty fallback when dotenv has not been initialized', () {
      expect(RuntimeEnvironmentValues.localEnvValue('MISSING_KEY'), '');
    });

    test('does not throw when Stripe dart-define and dotenv are both absent', () {
      expect(RuntimeEnvironmentValues.stripePublishableKey, '');
    });
  });
}
