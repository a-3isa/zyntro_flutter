import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clean-arch migration ADR pauses non-auth enforcement (Z-ARCH-001)', () {
    final doc = File('docs/ARCHITECTURE_MIGRATION.md').readAsStringSync();

    expect(doc, contains('paused'));
    expect(doc, contains('`auth`'));
    expect(doc, contains('advisory'));
    expect(doc, contains('Z-ARCH-001'));
    expect(doc, contains('validate_feature_layers'));
  });
}
