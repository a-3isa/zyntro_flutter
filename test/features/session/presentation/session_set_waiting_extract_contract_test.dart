import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session set-column builder + waiting partner extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/session/presentation/widgets/session_set_column_builder.dart',
      ).readAsStringSync(),
      contains('buildSessionSetColumn'),
    );
    expect(
      File(
        'lib/features/session/presentation/waiting_turn_partner.dart',
      ).readAsStringSync(),
      contains('resolveWaitingTurnPartner'),
    );
    expect(
      File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync(),
      contains('buildSessionSetColumn('),
    );
    expect(
      File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync(),
      contains('resolveWaitingTurnPartner('),
    );
  });
}
