import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session header chips extracted (Z-ARCH-002)', () {
    final widgets = File(
      'lib/features/session/presentation/widgets/session_header_chips.dart',
    ).readAsStringSync();
    expect(widgets, contains('class SessionSetupWaitingChip'));
    expect(widgets, contains('class SessionInviteAttentionChip'));

    final page = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync();
    expect(page, contains('SessionSetupWaitingChip'));
    expect(page, contains('SessionInviteAttentionChip'));
  });
}
