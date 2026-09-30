import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('start session plan widgets extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/session/presentation/widgets/start_session_plan_widgets.dart',
      ).readAsStringSync(),
      contains('class StartSessionExercisePlanRow'),
    );
    expect(
      File(
        'lib/features/session/presentation/start_session_page.dart',
      ).readAsStringSync(),
      contains('StartSessionExercisePlanRow('),
    );
    expect(
      File(
        'lib/features/session/presentation/start_session_page.dart',
      ).lengthSync(),
      lessThanOrEqualTo(45 * 1024),
    );
  });
}
