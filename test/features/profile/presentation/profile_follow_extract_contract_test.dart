import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile follow button extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/profile/presentation/widgets/profile_follow_button.dart',
      ).readAsStringSync(),
      contains('class ProfileFollowButton'),
    );
    final page = File(
      'lib/features/profile/presentation/profile_page.dart',
    ).readAsStringSync();
    expect(page, contains('ProfileFollowButton'));
    expect(page, isNot(contains('class _FollowButton')));
  });
}
