import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile posts tab extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/profile/presentation/widgets/profile_posts_tab.dart',
      ).readAsStringSync(),
      contains('class ProfilePostsTab'),
    );
    final page = File(
      'lib/features/profile/presentation/profile_page.dart',
    ).readAsStringSync();
    expect(page, contains('ProfilePostsTab'));
    expect(page, isNot(contains('class _PostsTab')));
  });
}
