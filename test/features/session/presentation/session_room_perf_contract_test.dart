import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session room clock ticks via ValueNotifier not setState (Z-PERF-001)',
      () {
    final source = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync();

    expect(source, contains('ValueNotifier<Duration> _elapsedNotifier'));
    expect(source, contains('ValueListenableBuilder<Duration>'));
    expect(source, contains('_elapsedNotifier.value = elapsed'));
    expect(source, contains('RepaintBoundary('));
    // Timer tick must not wrap elapsed updates in setState.
    expect(
      source,
      isNot(
        contains(RegExp(
          r'Timer\.periodic\([\s\S]*?setState\(\(\) \{\s*_elapsedTime',
        )),
      ),
    );
  });
}
