import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile empty states extracted from god file (Z-ARCH-002)', () {
    final widgets = File(
      'lib/features/profile/presentation/widgets/profile_empty_states.dart',
    ).readAsStringSync();
    expect(widgets, contains('class ProfileEmptyPosts'));
    expect(widgets, contains('class ProfilePrivateLocked'));

    // The posts tab was later extracted from the page too (ProfilePostsTab);
    // the page plus that tab are what the god file used to be.
    final page = File(
      'lib/features/profile/presentation/profile_page.dart',
    ).readAsStringSync() +
        File(
          'lib/features/profile/presentation/widgets/profile_posts_tab.dart',
        ).readAsStringSync();
    expect(page, contains('ProfileEmptyPosts'));
    expect(page, contains('ProfilePrivateLocked'));
    expect(page, isNot(contains('Widget _buildEmpty(')));
  });
}
