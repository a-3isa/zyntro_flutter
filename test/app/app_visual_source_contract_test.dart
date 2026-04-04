import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('targeted screens no longer use glow wrappers or premium gradients', () {
    const files = [
      'lib/features/session/presentation/start_session_page.dart',
      'lib/features/auth/presentation/onboarding_page.dart',
      'lib/features/auth/presentation/login_page.dart',
      'lib/features/auth/presentation/signup_page.dart',
      'lib/features/auth/presentation/forgot_password_page.dart',
      'lib/features/profile/presentation/profile_page.dart',
      'lib/features/profile/presentation/edit_profile_page.dart',
      'lib/features/session/presentation/session_page.dart',
      'lib/features/session/presentation/recap_page.dart',
      'lib/features/settings/presentation/settings_page.dart',
      'lib/widgets/streak_card.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source.contains('GlowContainer('), isFalse,
          reason: '$path still uses GlowContainer');
      expect(source.contains('PulsingGlow('), isFalse,
          reason: '$path still uses PulsingGlow');
      expect(source.contains('AppColors.premiumGradient'), isFalse,
          reason: '$path still uses AppColors.premiumGradient');
    }
  });
}
