import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';
import 'package:zyntro_flutter/widgets/premium_effects.dart';

void main() {
  test('glow helpers default to figma-aligned non-glow styling', () {
    const glow = GlowContainer(child: SizedBox());
    const pulse = PulsingGlow(child: SizedBox());
    const text = GradientText(text: 'Train');
    const border = GradientBorder(child: SizedBox());

    expect(glow.glowColor, Colors.transparent);
    expect(glow.blurRadius, 0);
    expect(pulse.glowColor, Colors.transparent);
    expect(pulse.maxRadius, 0);
    expect(text.colors, const [AppColors.textDark, AppColors.neonGreen]);
    expect(border.gradientColors, AppColors.primaryGradient);
  });

  test('shared primitives no longer reference legacy cyan or purple defaults',
      () {
    final effects =
        File('lib/widgets/premium_effects.dart').readAsStringSync();
    final animations =
        File('lib/widgets/premium_animations.dart').readAsStringSync();
    final button = File('lib/widgets/zyntro_button.dart').readAsStringSync();
    final streakCard = File('lib/widgets/streak_card.dart').readAsStringSync();
    final startSessionPage =
        File('lib/features/session/presentation/start_session_page.dart')
            .readAsStringSync();
    final sessionPage =
        File('lib/features/session/presentation/session_page.dart')
            .readAsStringSync();

    expect(effects.contains('0xFF00D9FF'), isFalse);
    expect(effects.contains('0xFF9D4EDD'), isFalse);
    expect(animations.contains('0xFF00D9FF'), isFalse);
    expect(animations.contains('0xFF9D4EDD'), isFalse);
    expect(button.contains('AppColors.primaryGlow.withValues'), isFalse);
    expect(button.contains('AppColors.secondaryGlow.withValues'), isFalse);
    expect(button.contains('AppColors.premiumGlow.withValues'), isFalse);
    expect(button.contains('AppColors.cardGradient'), isFalse);
    expect(button.contains('AppColors.premiumGradient'), isTrue);
    expect(button.contains('AppColors.textDark'), isTrue);
    expect(streakCard.contains('AppColors.secondaryGlow'), isFalse);
    expect(streakCard.contains('AppColors.warmBorder'), isTrue);
    expect(startSessionPage.contains('ZyntroButtonVariant.premium'), isFalse);
    expect(startSessionPage.contains('ZyntroButtonVariant.primary'), isTrue);
    expect(sessionPage.contains('ZyntroButtonVariant.premium'), isTrue);
    expect(sessionPage.contains('ZyntroButtonVariant.primary'), isTrue);
  });

  test('start session button content has horizontal breathing room', () {
    final startSessionPage =
        File('lib/features/session/presentation/start_session_page.dart')
            .readAsStringSync();

    expect(
      startSessionPage.contains(
        'padding: const EdgeInsets.symmetric(horizontal: 20),',
      ),
      isTrue,
    );
  });
}
