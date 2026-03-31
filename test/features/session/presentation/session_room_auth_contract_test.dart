import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session_room_page uses migrated auth providers', () {
    final file = File(
      'lib/features/session/presentation/session_room_page.dart',
    );
    final source = file.readAsStringSync();

    expect(source, isNot(contains("import '../../../services/auth_service.dart';")));
    expect(source, isNot(contains('authStateProvider')));
    expect(source, isNot(contains('firestoreProvider')));
    expect(source, contains('authSessionProvider'));
    expect(source, contains('authFirestoreProvider'));
  });
}
