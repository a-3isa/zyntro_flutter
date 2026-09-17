import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared chrome no longer references leftover neonGreen', () {
    const files = [
      'lib/widgets/reaction_buttons.dart',
      'lib/widgets/premium_effects.dart',
      'lib/features/auth/presentation/onboarding_page.dart',
    ];

    for (final path in files) {
      expect(
        File(path).readAsStringSync().contains('AppColors.neonGreen'),
        isFalse,
        reason: '$path still paints chrome with leftover neonGreen',
      );
    }
  });

  test('Android 12 splash uses concrete charcoal', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('color: "#1A1A18"'));
    expect(pubspec, contains('icon_background_color: "#1A1A18"'));

    for (final path in [
      'android/app/src/main/res/values-v31/styles.xml',
      'android/app/src/main/res/values-night-v31/styles.xml',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('#1A1A18'),
        reason: path,
      );
    }
  });
}
