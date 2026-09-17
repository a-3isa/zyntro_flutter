import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supported platforms ADR lists mobile-only matrix (Z-PLAT-001)', () {
    final source = File('docs/SUPPORTED_PLATFORMS.md').readAsStringSync();

    expect(source, contains('Android'));
    expect(source, contains('iOS'));
    expect(source, contains('| Linux | No |'));
    expect(source, contains('| macOS | No |'));
    expect(source, contains('mobile-only'));
  });
}
