import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';

void main() {
  group('AppFonts', () {
    test('primary is Bricolage Grotesque', () {
      expect(AppFonts.primary, 'Bricolage Grotesque');
    });
    test('display is Barlow Condensed', () {
      expect(AppFonts.display, 'Barlow Condensed');
    });
  });

  group('AppTextStyles dual register', () {
    test('wordmark and session stats use Barlow; body uses Bricolage', () {
      final source =
          File('lib/core/theme/app_text_styles.dart').readAsStringSync();
      expect(
        source.contains('get wordmark => GoogleFonts.barlowCondensed'),
        isTrue,
      );
      expect(
        source.contains('get sessionStat => GoogleFonts.barlowCondensed'),
        isTrue,
      );
      expect(
        source.contains('get bodyLarge => GoogleFonts.bricolageGrotesque'),
        isTrue,
      );
    });
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

  group('AppColors brand tokens', () {
    test('signal is safety orange, not acid lime', () {
      expect(AppColors.signal, const Color(0xFFFF5C1A));
      expect(AppColors.signal, isNot(const Color(0xFFC8FF00)));
      expect(AppColors.accentLime, AppColors.signal);
    });

    test('primaryGlow is not transparent', () {
      expect(AppColors.primaryGlow, isNot(Colors.transparent));
    });
  });
}
