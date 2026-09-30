import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('high-contrast theme + settings toggle shipped (Z-ENH-029)', () {
    expect(
      File('lib/core/theme/app_theme.dart').readAsStringSync(),
      contains('highContrastDarkTheme'),
    );
    expect(
      File('lib/core/theme/theme_provider.dart').readAsStringSync(),
      contains('highContrastProvider'),
    );
    expect(
      File('lib/features/settings/presentation/settings_page.dart')
          .readAsStringSync(),
      contains('High contrast'),
    );
    expect(
      File('lib/app/app.dart').readAsStringSync(),
      contains('highContrastPref'),
    );
  });
}
