import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CI pins Flutter 3.44.4 and enforces a coverage floor (Z-CI-001 / Z-TEST-001)', () {
    final ci = File('.github/workflows/flutter-ci.yml').readAsStringSync();
    expect(ci, contains("flutter-version: '3.44.4'"));
    expect(ci, isNot(contains("flutter-version: '3.38.9'")));
    expect(ci, contains('flutter test --coverage'));
    expect(ci, contains('coverage {pct:.2f}% below 30% floor'));
  });
}
