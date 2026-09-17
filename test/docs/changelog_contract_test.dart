import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CHANGELOG Unreleased covers audit-closure themes (Z-DOC-002)', () {
    final text = File('CHANGELOG.md').readAsStringSync();
    expect(text, contains('## [Unreleased]'));
    expect(text, contains('aps-environment'));
    expect(text, contains('Arabic push'));
    expect(text, contains('Payments'));
    expect(text, isNot(contains('CHANGELOG placeholder')));
  });
}
