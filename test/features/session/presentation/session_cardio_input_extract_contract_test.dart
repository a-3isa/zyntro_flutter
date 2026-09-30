import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session cardio input extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/session/presentation/widgets/session_cardio_input.dart',
      ).readAsStringSync(),
      contains('class SessionCardioInputSection'),
    );
    expect(
      File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync(),
      contains('SessionCardioInputSection('),
    );
  });
}
