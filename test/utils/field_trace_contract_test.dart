import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('field traces cover startup and session join (Z-OBS-001)', () {
    expect(File('lib/utils/field_trace.dart').existsSync(), isTrue);
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains("FieldTrace('startup_to_first_frame')"));
    final session = File('lib/services/session_service.dart').readAsStringSync();
    expect(session, contains("FieldTrace.measure('session_join'"));
    expect(session, contains("FieldTrace.measure('session_resume_lookup'"));
  });
}
