import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session room guards system back with PopScope (Z-UI-002)', () {
    final room = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync();
    expect(room, contains('PopScope('));
    expect(room, contains('canPop: false'));
    expect(room, contains('Z-UI-002'));

    final doc = File('docs/THEME_TOKENS.md').readAsStringSync();
    expect(doc, contains('AppColors'));
    expect(doc, contains('Z-UI-002'));
  });

  test('dependency upgrade runbook exists (Z-DEP-003)', () {
    final doc = File('docs/DEPENDENCY_UPGRADES.md').readAsStringSync();
    expect(doc, contains('Z-DEP-003'));
    expect(doc, contains('Dynamic Links'));
  });
}
