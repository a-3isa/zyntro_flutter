import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';
import 'package:zyntro_flutter/widgets/premium_animations.dart';
import 'package:zyntro_flutter/widgets/premium_effects.dart';
import 'package:zyntro_flutter/widgets/zyntro_card.dart';

void main() {
  test('glow and gradient helpers default to figma-aligned styling', () {
    const glow = GlowContainer(child: SizedBox());
    const pulse = PulsingGlow(child: SizedBox());
    const text = GradientText(text: 'Train');
    const border = GradientBorder(child: SizedBox());
    const animatedBorder = GradientBorderAnimation(child: SizedBox());

    expect(glow.glowColor, Colors.transparent);
    expect(glow.blurRadius, 0);
    expect(glow.spreadRadius, 0);
    expect(pulse.glowColor, Colors.transparent);
    expect(pulse.minRadius, 0);
    expect(pulse.maxRadius, 0);
    expect(text.colors, const [AppColors.textDark, AppColors.neonGreen]);
    expect(border.gradientColors, AppColors.primaryGradient);
    expect(animatedBorder.gradientColors, AppColors.primaryGradient);
  });

  testWidgets('zyntro card showGlow uses a neutral depth shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ZyntroCard(
            showGlow: true,
            child: SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );

    final decoratedContainer = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(ZyntroCard),
            matching: find.byType(Container),
          ),
        )
        .firstWhere((container) => container.decoration is BoxDecoration);
    final decoration = decoratedContainer.decoration! as BoxDecoration;
    final shadow = decoration.boxShadow!.single;

    expect(shadow.color, const Color(0x22000000));
    expect(shadow.blurRadius, 14);
    expect(shadow.offset, const Offset(0, 6));
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
