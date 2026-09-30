import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session V2 header extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/session/presentation/widgets/session_v2_header.dart',
      ).readAsStringSync(),
      contains('class SessionV2Header'),
    );
    expect(
      File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync(),
      contains('SessionV2Header('),
    );
  });
}
