import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup stack traces stay debug-only', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('void _debugPrintStartupFailure('));
    expect(source, contains('if (kDebugMode && stackTrace != null)'));
    expect(source, isNot(contains(r"debugPrint('[AppCheck] Activation failed (non-fatal): $e\n$st');")));
    expect(source, isNot(contains(r"debugPrint('[NotificationService] Init failed (non-fatal): $e\n$st');")));
    expect(source, isNot(contains(r"debugPrint('[StorageService] Init failed (non-fatal): $e\n$st');")));
    expect(source, isNot(contains(r"debugPrint('[OfflineHandlers] Init failed (non-fatal): $e\n$st');")));
  });
}
