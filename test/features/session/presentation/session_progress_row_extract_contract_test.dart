import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session progress row extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/session/presentation/widgets/session_progress_row.dart',
      ).readAsStringSync(),
      contains('class SessionProgressRow'),
    );
    expect(
      File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync(),
      contains('SessionProgressRow('),
    );
  });
}
