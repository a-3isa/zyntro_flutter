import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('social buddy widgets extracted from god file (Z-ARCH-002)', () {
    final widgets = File(
      'lib/features/social/presentation/widgets/social_buddy_widgets.dart',
    ).readAsStringSync();
    expect(widgets, contains('class SocialBuddyRow'));
    expect(widgets, contains('class SocialBuddySkeleton'));
    expect(widgets, contains('class SocialFacebookConnectBanner'));

    final page = File(
      'lib/features/social/presentation/social_page.dart',
    ).readAsStringSync();
    expect(page, contains('SocialBuddyRow'));
    expect(page, contains('SocialBuddySkeleton'));
    expect(page, contains('SocialFacebookConnectBanner'));
    expect(page, isNot(contains('Widget _buildBuddyRow(')));
    expect(page, isNot(contains('Widget _buildBuddySkeleton(')));
    expect(page, isNot(contains('Widget _buildFacebookConnectBanner(')));
  });
}
