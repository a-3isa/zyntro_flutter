import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main shell and social use ARB nav strings (Z-I18N-001 slice)', () {
    final en = File('lib/l10n/app_en.arb').readAsStringSync();
    final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
    final shell =
        File('lib/features/main/presentation/main_shell.dart').readAsStringSync();
    final social = File(
      'lib/features/social/presentation/social_page.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/settings/presentation/settings_page.dart',
    ).readAsStringSync();

    for (final key in [
      'navFeed',
      'navProfile',
      'navTrain',
      'navStartSession',
      'settingsTitle',
      'socialTabBoard',
    ]) {
      expect(en, contains('"$key"'));
      expect(ar, contains('"$key"'));
    }

    expect(shell, contains('l10n.navFeed'));
    expect(shell, contains('l10n.navProfile'));
    expect(social, contains('socialTabBoard'));
    expect(settings, contains('settingsTitle'));
  });
}
