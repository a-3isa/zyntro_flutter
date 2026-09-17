import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session plan complete view extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/session/presentation/widgets/session_plan_complete_view.dart',
      ).readAsStringSync(),
      contains('class SessionPlanCompleteView'),
    );
    expect(
      File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync(),
      contains('SessionPlanCompleteView('),
    );
  });
}
