import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('media service always re-encodes images without EXIF (Z-PRV-004)', () {
    final source = File('lib/services/media_service.dart').readAsStringSync();
    expect(source, contains('keepExif: false'));
    expect(source, isNot(contains('no compression needed')));
    expect(source, contains('EXIF stripped'));
  });
}
