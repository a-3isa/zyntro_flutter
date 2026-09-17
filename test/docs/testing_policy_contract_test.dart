import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TESTING policy documents contract triage and integration gate (Z-TEST-005)', () {
    final text = File('docs/TESTING.md').readAsStringSync();
    expect(text, contains('Z-TEST-005'));
    expect(text, contains('Contract tests'));
    expect(text, contains('workflow_dispatch'));
    expect(text, contains('Goldens'));
  });

  test('CI workflow exposes integration smoke as dispatch-only', () {
    final text = File('.github/workflows/flutter-ci.yml').readAsStringSync();
    expect(text, contains('integration-smoke'));
    expect(text, contains('workflow_dispatch'));
    expect(text, contains('integration_test/smoke_test.dart'));
  });
}
