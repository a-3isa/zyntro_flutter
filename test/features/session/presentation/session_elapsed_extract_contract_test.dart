import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session elapsed timer chip is extracted from god file (Z-ARCH-002)', () {
    final chip = File(
      'lib/features/session/presentation/widgets/session_elapsed_timer_chip.dart',
    ).readAsStringSync();
    expect(chip, contains('class SessionElapsedTimerChip'));
    expect(chip, contains('Z-ARCH-002'));

    final room = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync();
    expect(room, contains('SessionElapsedTimerChip('));
    expect(room, contains('session_elapsed_timer_chip.dart'));

    final adr = File('docs/ARCHITECTURE_MIGRATION.md').readAsStringSync();
    expect(adr, contains('Z-ARCH-002'));
    expect(adr, contains('session_elapsed_timer_chip.dart'));
  });
}
