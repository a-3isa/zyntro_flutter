import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session sync status dialog extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/session/presentation/widgets/session_sync_status_dialog.dart',
      ).readAsStringSync(),
      contains('class SessionSyncStatusDialog'),
    );
    expect(
      File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync(),
      contains('SessionSyncStatusDialog.show'),
    );
  });
}
