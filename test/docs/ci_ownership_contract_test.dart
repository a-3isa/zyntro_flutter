import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CI ownership doc pins GHA as gate source of truth (Z-CI-002)', () {
    final ciDoc = File('docs/CI.md').readAsStringSync();
    final gha = File('.github/workflows/flutter-ci.yml').readAsStringSync();
    final cm = File('codemagic.yaml').readAsStringSync();

    expect(ciDoc, contains('GitHub Actions'));
    expect(ciDoc, contains('Codemagic'));
    expect(ciDoc, contains('Required quality gates'));
    expect(ciDoc, contains('3.44.4'));

    expect(gha, contains("flutter-version: '3.44.4'"));
    expect(cm, isNot(contains('3.38.9')));
    expect(cm, contains('flutter: 3.44.4'));
  });
}
