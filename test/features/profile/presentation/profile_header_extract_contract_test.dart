import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile header widgets extracted (Z-ARCH-002)', () {
    final widgets = File(
      'lib/features/profile/presentation/widgets/profile_header_widgets.dart',
    ).readAsStringSync();
    expect(widgets, contains('class ProfileVisitorChip'));
    expect(widgets, contains('class ProfileStatsRow'));

    final page = File(
      'lib/features/profile/presentation/profile_page.dart',
    ).readAsStringSync();
    expect(page, contains('ProfileVisitorChip'));
    expect(page, contains('ProfileStatsRow'));
    expect(page, contains('profile_header_widgets.dart'));
    expect(page, isNot(contains('class _VisitorChip')));
    expect(page, isNot(contains('class _StatsRow')));
  });
}
