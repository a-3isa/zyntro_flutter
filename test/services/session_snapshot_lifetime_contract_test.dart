import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session snapshot providers are autoDispose (Z-PERF-002)', () {
    final source = File('lib/services/session_service.dart').readAsStringSync();
    expect(source, contains('Session live-snapshot lifetime map (Z-PERF-002)'));
    expect(
      source,
      contains(
        'adaptiveDebouncedSessionEventsProvider =\n    StreamProvider.autoDispose.family',
      ),
    );
    expect(
      source,
      contains(
        'configurableDebouncedSessionEventsProvider =\n    StreamProvider.autoDispose.family',
      ),
    );
    // No lingering non-autoDispose session event StreamProviders.
    expect(
      source.contains('StreamProvider.family<List<TimelineEvent>, String>'),
      isFalse,
    );
  });
}
