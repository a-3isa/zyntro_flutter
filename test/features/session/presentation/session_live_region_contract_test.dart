import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session room announces turn and partner-left for a11y (Z-A11Y-004)', () {
    final source = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync();

    expect(source, contains("SemanticsService.announce(\"It's your turn\""));
    expect(source, contains('left the session'));
    expect(source, contains('package:flutter/semantics.dart'));
  });
}
