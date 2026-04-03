import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main shell source uses the approved navy and neon theme tokens', () {
    final source = File(
      'lib/features/main/presentation/main_shell.dart',
    ).readAsStringSync();

    expect(
      source.contains('AppColors.navy800.withValues(alpha: 0.85)'),
      isTrue,
    );
    expect(source.contains('AppColors.navy700'), isTrue);
    expect(source.contains('AppColors.neonGreen'), isTrue);
    expect(source.contains('AppColors.gray400'), isTrue);
    expect(source.contains('AppColors.primaryGradient'), isTrue);
    expect(source.contains('AppColors.navy900'), isTrue);

    expect(source.contains('AppColors.primaryGlow.withValues'), isFalse);
    expect(source.contains('AppColors.primary,'), isFalse);
    expect(source.contains('AppColors.textTertiaryDark'), isFalse);
    expect(source.contains('Colors.white'), isFalse);
  });
}
