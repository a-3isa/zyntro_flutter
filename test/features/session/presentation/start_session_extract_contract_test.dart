import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('start session widgets extracted from god file (Z-ARCH-002)', () {
    final widgets = File(
      'lib/features/session/presentation/widgets/start_session_widgets.dart',
    ).readAsStringSync();
    expect(widgets, contains('class StartSessionTypeCard'));
    expect(widgets, contains('class StartSessionSectionLabel'));
    expect(widgets, contains('class StartSessionAvatarPlaceholder'));
    expect(widgets, contains('workoutTypeIconData'));

    final page = File(
      'lib/features/session/presentation/start_session_page.dart',
    ).readAsStringSync();
    expect(page, contains('StartSessionTypeCard'));
    expect(page, contains('StartSessionSectionLabel'));
    expect(page, contains('StartSessionAvatarPlaceholder'));
    expect(page, isNot(contains('Widget _buildTypeCard(')));
    expect(page, isNot(contains('Widget _buildSectionLabel(')));
    expect(page, isNot(contains('Widget _buildAvatarPlaceholder(')));
  });
}
