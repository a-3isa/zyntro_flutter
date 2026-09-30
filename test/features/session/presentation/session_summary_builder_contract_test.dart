import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session summary builder extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/session/presentation/session_summary_builder.dart',
      ).readAsStringSync(),
      contains('buildSessionSummary'),
    );
    expect(
      File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync(),
      contains('buildSessionSummary('),
    );
  });
}
