import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payments and offline ADRs record store and queue policy', () {
    final payments = File('docs/PAYMENTS.md').readAsStringSync();
    expect(payments, contains('Z-PAY-001'));
    expect(payments, contains('Z-PAY-002'));
    expect(payments, contains('platform billing'));
    expect(payments, contains('RevenueCat'));

    final offline = File('docs/OFFLINE_QUEUE.md').readAsStringSync();
    expect(offline, contains('Z-OFF-002'));
    expect(offline, contains('clientEventId'));
    expect(offline, contains('Firestore'));

    final deadlines = File('docs/PLATFORM_DEADLINES.md').readAsStringSync();
    expect(deadlines, contains('Z-DEP-001'));
    expect(deadlines, contains('Z-DEP-002'));
  });
}
