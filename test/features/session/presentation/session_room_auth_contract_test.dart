import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session room page reads auth directly from migrated auth providers', () {
    final source = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('services/auth_service.dart')));
    expect(source, isNot(contains('authStateProvider')));
    expect(source, isNot(contains('.uid')));
    expect(source, contains('authSessionProvider'));
  });
}
