import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('social find people-you-may-know extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/social/presentation/widgets/social_find_widgets.dart',
      ).readAsStringSync(),
      contains('class SocialPeopleYouMayKnow'),
    );
    expect(
      File(
        'lib/features/social/presentation/social_page.dart',
      ).readAsStringSync(),
      contains('SocialPeopleYouMayKnow('),
    );
  });
}
