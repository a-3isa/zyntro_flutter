import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('social board widgets extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/social/presentation/widgets/social_board_widgets.dart',
      ).readAsStringSync(),
      contains('class SocialBoardContent'),
    );
    expect(
      File(
        'lib/features/social/presentation/social_page.dart',
      ).readAsStringSync(),
      contains('SocialBoardContent('),
    );
    expect(
      File(
        'lib/features/social/presentation/social_page.dart',
      ).lengthSync(),
      lessThanOrEqualTo(40 * 1024),
    );
  });
}
