import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release CI builds use obfuscation (Z-CI-003)', () {
    final ci = File('.github/workflows/flutter-ci.yml').readAsStringSync();
    expect(ci, contains('--obfuscate'));
    expect(ci, contains('--split-debug-info=build/app/outputs/symbols'));
    expect(ci, contains('--split-debug-info=build/ios/symbols'));
    expect(ci, contains('android-debug-symbols'));
    expect(ci, contains('ios-debug-symbols'));
  });
}
