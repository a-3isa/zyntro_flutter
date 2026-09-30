import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session room animated background extracted (Z-ARCH-002)', () {
    final widgets = File(
      'lib/features/session/presentation/widgets/session_room_background.dart',
    ).readAsStringSync();
    expect(widgets, contains('class SessionRoomAnimatedBackground'));

    final page = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync();
    expect(page, contains('SessionRoomAnimatedBackground'));
    expect(page, isNot(contains('Widget _buildAnimatedBackground(')));
  });
}
