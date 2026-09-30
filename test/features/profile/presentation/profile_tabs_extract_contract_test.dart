import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile history and awards tabs extracted (Z-ARCH-002)', () {
    final tabs = File(
      'lib/features/profile/presentation/widgets/profile_tabs.dart',
    ).readAsStringSync();
    expect(tabs, contains('class ProfileHistoryTab'));
    expect(tabs, contains('class ProfileAwardsTab'));

    final page = File(
      'lib/features/profile/presentation/profile_page.dart',
    ).readAsStringSync();
    expect(page, contains('ProfileHistoryTab'));
    expect(page, contains('ProfileAwardsTab'));
    expect(page, isNot(contains('class _HistoryTab')));
    expect(page, isNot(contains('class _AwardsTab')));
  });
}
