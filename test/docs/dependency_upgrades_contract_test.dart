import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dependency upgrade runbook exists (Z-DEP-003)', () {
    final doc = File('docs/DEPENDENCY_UPGRADES.md').readAsStringSync();
    expect(doc, contains('Z-DEP-003'));
    expect(doc, contains('Node 22'));
    expect(doc, contains('Dynamic Links'));
    expect(doc, contains('docs/CI.md'));

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('firebase_dynamic_links')));
  });
}
