import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HTTP App Check verification consumes limited-use tokens (Z-FN-002)', () {
    final source = File('functions/index.js').readAsStringSync();
    expect(source, contains('verifyToken(token, { consume: true })'));
    expect(source, contains('requireHttpAppCheck'));
  });
}
