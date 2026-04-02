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

  test(
    'shared primitives no longer reference legacy cyan or purple defaults',
    () {
      final effects = File(
        'lib/widgets/premium_effects.dart',
      ).readAsStringSync();
      final animations = File(
        'lib/widgets/premium_animations.dart',
      ).readAsStringSync();
      final button = File('lib/widgets/zyntro_button.dart').readAsStringSync();

      expect(effects.contains('0xFF00D9FF'), isFalse);
      expect(effects.contains('0xFF9D4EDD'), isFalse);
      expect(animations.contains('0xFF00D9FF'), isFalse);
      expect(animations.contains('0xFF9D4EDD'), isFalse);
      expect(button.contains('AppColors.primaryGlow.withValues'), isFalse);
      expect(button.contains('AppColors.secondaryGlow.withValues'), isFalse);
      expect(button.contains('AppColors.premiumGlow.withValues'), isFalse);
    },
  );
}
