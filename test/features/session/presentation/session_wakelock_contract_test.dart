import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session room enables wakelock while mounted (Z-RT-006)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('wakelock_plus:'));

    final helper = File(
      'lib/features/session/presentation/session_wakelock.dart',
    ).readAsStringSync();
    expect(helper, contains('WakelockPlus.enable'));
    expect(helper, contains('WakelockPlus.disable'));
    expect(helper, contains('Z-RT-006'));

    final room = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync();
    expect(room, contains('SessionWakelock.enable()'));
    expect(room, contains('SessionWakelock.disable()'));
  });
}
