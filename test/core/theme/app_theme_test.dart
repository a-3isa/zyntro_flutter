import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';

void main() {
  group('AppFonts', () {
    test('primary is Outfit', () => expect(AppFonts.primary, 'Outfit'));
    test('display is Syne', () => expect(AppFonts.display, 'Syne'));
  });

  group('AppCurves', () {
    test('premium is custom Cubic', () {
      expect(AppCurves.premium, isA<Cubic>());
    });
    test('press is custom Cubic', () {
      expect(AppCurves.press, isA<Cubic>());
    });
  });

  group('AppSpacing', () {
    test('md is 12', () => expect(AppSpacing.md, 12.0));
    test('lg is 16', () => expect(AppSpacing.lg, 16.0));
  });

  group('AppColors glow tokens', () {
    test('primaryGlow is not transparent', () {
      expect(AppColors.primaryGlow, isNot(Colors.transparent));
    });
  });
}
