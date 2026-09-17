import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session set column extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/session/presentation/widgets/session_set_column.dart',
      ).readAsStringSync(),
      contains('class SessionSetColumn'),
    );
    expect(
      File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync(),
      contains('SessionSetColumn('),
    );
  });
}
