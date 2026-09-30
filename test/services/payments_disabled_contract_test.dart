import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payments stay feature-flagged off (Z-PAY-001 / Z-PAY-002)', () {
    final flags = File('lib/core/constants/feature_flags.dart').readAsStringSync();
    expect(flags, contains('isPaymentsEnabled => false'));

    final payments = File('lib/services/payment_service.dart').readAsStringSync();
    expect(payments, contains('FeatureFlags.isPaymentsEnabled'));
    expect(payments, contains('Z-PAY-001'));
    expect(payments, contains('UnsupportedError'));
  });
}
