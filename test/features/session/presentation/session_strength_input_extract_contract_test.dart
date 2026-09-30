import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session strength input extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/session/presentation/widgets/session_strength_input.dart',
      ).readAsStringSync(),
      contains('class SessionStrengthInputSection'),
    );
    expect(
      File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync(),
      contains('SessionStrengthInputSection('),
    );
  });
}
