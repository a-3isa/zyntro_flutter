import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app palette matches approved figma colors', () {
    expect(AppColors.navy900, const Color(0xFF0A0E27));
    expect(AppColors.navy800, const Color(0xFF151B3D));
    expect(AppColors.navy700, const Color(0xFF1E2749));
    expect(AppColors.neonGreen, const Color(0xFF39FF14));
    expect(AppColors.neonGreenHover, const Color(0xFF2EE00F));
    expect(AppColors.gray400, const Color(0xFF8B8B98));
    expect(AppColors.gray300, const Color(0xFFA0A0AC));
    expect(AppColors.primaryGlow, Colors.transparent);
    expect(AppColors.secondaryGlow, Colors.transparent);
    expect(AppColors.premiumGlow, Colors.transparent);
  });

  test('dark theme maps figma surfaces and accent roles correctly', () {
    final theme = AppTheme.darkTheme;

    expect(theme.scaffoldBackgroundColor, AppColors.navy900);
    expect(theme.colorScheme.primary, AppColors.neonGreen);
    expect(theme.colorScheme.surface, AppColors.navy800);
    expect(theme.colorScheme.secondary, AppColors.gray400);
    expect(theme.colorScheme.tertiary, AppColors.navy700);
    expect(theme.bottomNavigationBarTheme.selectedItemColor, AppColors.neonGreen);
    expect(theme.bottomNavigationBarTheme.unselectedItemColor, AppColors.gray400);
  });
}
