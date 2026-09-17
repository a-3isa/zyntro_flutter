import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile buddies sheet extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/profile/presentation/widgets/profile_buddies_sheet.dart',
      ).readAsStringSync(),
      contains('class ProfileBuddiesSheet'),
    );
    final page = File(
      'lib/features/profile/presentation/profile_page.dart',
    ).readAsStringSync();
    expect(page, isNot(contains('class _BuddiesSheet')));
  });
}
