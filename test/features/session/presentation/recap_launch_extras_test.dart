import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/features/session/presentation/recap_launch_extras.dart';

void main() {
  tearDown(RecapLaunchExtras.take);

  test('RecapLaunchExtras stages and takes once (Z-ENH-007)', () {
    RecapLaunchExtras.stage(
      const RecapLaunchExtras(newStrengthPrNames: ['bench press']),
    );
    final first = RecapLaunchExtras.take();
    expect(first, isNotNull);
    expect(first!.hasNewPrs, isTrue);
    expect(first.newStrengthPrNames, ['bench press']);
    expect(RecapLaunchExtras.take(), isNull);
  });
}
