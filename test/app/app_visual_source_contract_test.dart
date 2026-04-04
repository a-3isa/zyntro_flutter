import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'targeted theme migration files do not use legacy glow wrappers or premium gradient token',
    () {
      const targetedFiles = <String>[
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

      const bannedTokens = <String>[
        'GlowContainer(',
        'PulsingGlow(',
        'AppColors.premiumGradient',
      ];

      for (final relativePath in targetedFiles) {
        final source = File(relativePath).readAsStringSync();

        for (final bannedToken in bannedTokens) {
          expect(
            source,
            isNot(contains(bannedToken)),
            reason: '$relativePath still contains $bannedToken',
          );
        }
      }
    },
  );
}
