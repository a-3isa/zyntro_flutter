import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session header avatar extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/session/presentation/widgets/session_header_avatar.dart',
      ).readAsStringSync(),
      contains('class SessionHeaderAvatar'),
    );
    expect(
      File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync(),
      contains('SessionHeaderAvatar('),
    );
  });
}
