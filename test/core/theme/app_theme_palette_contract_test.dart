import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('app palette matches approved figma colors', () {
    expect(AppColors.navy900, const Color(0xFF0A0E27));
    expect(AppColors.navy800, const Color(0xFF151B3D));
    expect(AppColors.navy700, const Color(0xFF1E2749));
    expect(AppColors.neonGreen, const Color(0xFF39FF14));
    expect(AppColors.neonGreenHover, const Color(0xFF2EE00F));
    expect(AppColors.gray400, const Color(0xFF8B8B98));
    expect(AppColors.gray300, const Color(0xFFA0A0AC));
    // Glow tokens updated to lime-tinted values per design overhaul
    expect(AppColors.primaryGlow, const Color(0x33C8FF00));
    expect(AppColors.secondaryGlow, const Color(0x1A888888));
    expect(AppColors.premiumGlow, const Color(0x1AC8FF00));
  });

  testWidgets('dark theme maps figma surfaces and accent roles correctly',
      (tester) async {
    final theme = AppTheme.darkTheme;

    expect(theme.scaffoldBackgroundColor, AppColors.backgroundV2);
    expect(theme.colorScheme.primary, AppColors.accentLime);
    expect(theme.colorScheme.surface, AppColors.surfaceV2);
    expect(theme.colorScheme.secondary, AppColors.textV2Secondary);
    expect(theme.colorScheme.tertiary, AppColors.surfaceV2Active);
    expect(
        theme.bottomNavigationBarTheme.selectedItemColor, AppColors.accentLime);
    expect(
        theme.bottomNavigationBarTheme.unselectedItemColor,
        AppColors.textV2Secondary);
  });
}
