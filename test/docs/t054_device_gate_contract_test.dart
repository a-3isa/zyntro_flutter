import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('T054 device gate runbook exists for Z-REPO-004', () {
    final text = File('docs/T054_DEVICE_GATE.md').readAsStringSync();
    expect(text, contains('Z-REPO-004'));
    expect(text, contains('US1'));
    expect(text, contains('force-close'));
    expect(text, contains('docs/evidence/t054-'));
  });

  test('007 tasks still list T054 as the device gate', () {
    final text =
        File('specs/007-resume-active-session/tasks.md').readAsStringSync();
    expect(text, contains('T054'));
    expect(text, contains('physical'));
  });
}
