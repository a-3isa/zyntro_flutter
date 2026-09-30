import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile action row extracted (Z-ARCH-002)', () {
    expect(
      File(
        'lib/features/profile/presentation/widgets/profile_action_row.dart',
      ).readAsStringSync(),
      contains('class ProfileActionRow'),
    );
    final page = File(
      'lib/features/profile/presentation/profile_page.dart',
    ).readAsStringSync();
    expect(page, contains('ProfileActionRow'));
    expect(page, isNot(contains('class _ActionRow')));
  });
}
