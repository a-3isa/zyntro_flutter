import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session voice/progress/late-add helpers extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/session/presentation/session_voice_note_upload.dart',
      ).readAsStringSync(),
      contains('uploadOrQueueSessionVoiceNote'),
    );
    expect(
      File(
        'lib/features/session/presentation/live_progress_map.dart',
      ).readAsStringSync(),
      contains('liveProgressFromServiceMap'),
    );
    expect(
      File(
        'lib/features/session/presentation/late_add_plan.dart',
      ).readAsStringSync(),
      contains('appendLateExercisesToPlan'),
    );
    expect(
      File(
        'lib/features/session/presentation/active_turn_prefill.dart',
      ).readAsStringSync(),
      contains('resolveActiveTurnPrefill'),
    );
    expect(
      File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync(),
      contains('uploadOrQueueSessionVoiceNote('),
    );
    final roomBytes = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).lengthSync();
    expect(roomBytes, lessThanOrEqualTo(80 * 1024));
  });
}
