import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session end confirm dialog extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/session/presentation/widgets/session_end_confirm_dialog.dart',
      ).readAsStringSync(),
      contains('class SessionEndConfirmDialog'),
    );
    expect(
      File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync(),
      contains('SessionEndConfirmDialog.show'),
    );
  });
}
