import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session parallel partner factory extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/session/presentation/widgets/parallel_gym_view.dart',
      ).readAsStringSync(),
      contains('factory ParallelPartnerData.fromProgress'),
    );
    expect(
      File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync(),
      contains('_parallelPartnerData('),
    );
    expect(
      File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync(),
      isNot(contains('totalDistance: partnerProgress?.totalDistance')),
    );
  });
}
