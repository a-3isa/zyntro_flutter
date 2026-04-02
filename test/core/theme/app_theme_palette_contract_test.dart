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
    expect(AppColors.backgroundLight, const Color(0xFFF5F7FA));
    expect(AppColors.surfaceSecondaryLight, const Color(0xFFEAEEF5));
    expect(AppColors.primaryGlow, Colors.transparent);
    expect(AppColors.secondaryGlow, Colors.transparent);
    expect(AppColors.premiumGlow, Colors.transparent);
    expect(AppColors.errorGlow, Colors.transparent);
  });

  test('semantic aliases stay mapped to the figma palette', () {
    expect(AppColors.primary, AppColors.neonGreen);
    expect(AppColors.primaryDark, AppColors.neonGreenHover);
    expect(AppColors.primaryLight, const Color(0xFF6CFF52));
    expect(AppColors.action, AppColors.neonGreen);
    expect(AppColors.actionLight, const Color(0xFF6CFF52));
    expect(AppColors.secondary, AppColors.gray400);
    expect(AppColors.secondaryDark, AppColors.gray300);
    expect(AppColors.accent, AppColors.navy700);
    expect(AppColors.premium, AppColors.navy800);
    expect(AppColors.success, AppColors.neonGreen);
    expect(AppColors.successDark, AppColors.neonGreenHover);
    expect(AppColors.secondaryLight, const Color(0xFFC7C7D1));
    expect(AppColors.info, AppColors.gray400);
    expect(AppColors.backgroundDark, AppColors.navy900);
    expect(AppColors.surfaceDark, AppColors.navy800);
    expect(AppColors.surfaceSecondaryDark, AppColors.navy700);
    expect(AppColors.textSecondaryDark, AppColors.gray300);
    expect(AppColors.textTertiaryDark, AppColors.gray400);
    expect(AppColors.borderDark, AppColors.navy700);
    expect(AppColors.gradientStart, AppColors.navy900);
    expect(AppColors.gradientMiddle, AppColors.navy800);
    expect(AppColors.gradientEnd, AppColors.neonGreen);
    expect(AppColors.warmBackground, AppColors.navy900);
    expect(AppColors.warmBorder, AppColors.neonGreenHover);
    expect(AppColors.warmAccent, AppColors.neonGreen);
    expect(AppColors.borderDarkSecondary, const Color(0xFF263156));
    expect(AppColors.surfaceElevatedDark, const Color(0xFF22305B));
  });

  test('key gradients stay on the figma palette', () {
    expect(AppColors.primaryGradient, [AppColors.neonGreen, AppColors.neonGreenHover]);
    expect(AppColors.secondaryGradient, [AppColors.navy700, AppColors.navy800]);
    expect(AppColors.premiumGradient, [AppColors.navy800, AppColors.navy700]);
    expect(AppColors.splashGradient, [AppColors.navy900, AppColors.navy800, AppColors.navy700]);
    expect(AppColors.successGradient, [AppColors.neonGreen, AppColors.neonGreenHover]);
    expect(AppColors.motivationalGradient, [AppColors.navy700, AppColors.neonGreen]);
    expect(AppColors.achievementGradient, [AppColors.navy800, AppColors.neonGreen]);
    expect(AppColors.streakGradient, [AppColors.navy700, AppColors.navy800, AppColors.neonGreenHover]);
    expect(AppColors.cardGradient, [AppColors.navy800, AppColors.navy700]);
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
    expect(theme.cardTheme.color, AppColors.navy800);
    expect(theme.inputDecorationTheme.fillColor, AppColors.navy700);
    expect(theme.dividerTheme.color, AppColors.navy700);
    expect(
      theme.elevatedButtonTheme.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.neonGreen,
    );
    expect(
      theme.elevatedButtonTheme.style?.foregroundColor?.resolve(<WidgetState>{}),
      AppColors.navy900,
    );
  });
}
