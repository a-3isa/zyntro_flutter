import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('app palette matches concrete / iron / signal brand', () {
    expect(AppColors.backgroundV2, const Color(0xFF1A1A18));
    expect(AppColors.surfaceV2, const Color(0xFF2C2A27));
    expect(AppColors.surfaceV2Elevated, const Color(0xFF35322E));
    expect(AppColors.surfaceV2Active, const Color(0xFF3F3C37));
    expect(AppColors.backgroundV2Light, const Color(0xFFE8E4DC));
    expect(AppColors.surfaceV2Light, const Color(0xFFF7F4EE));
    expect(AppColors.signal, const Color(0xFFFF5C1A));
    expect(AppColors.neonGreen, AppColors.signal);
    expect(AppColors.neonGreenHover, AppColors.signalDim);
    expect(AppColors.signalDim, const Color(0xFFE04810));
    expect(AppColors.signalLight, const Color(0xFFC7420F));
    expect(AppColors.primaryGlow, const Color(0x33FF5C1A));
    expect(AppColors.premiumGlow, const Color(0x1AFF5C1A));
  });

  testWidgets('dark theme maps concrete surfaces and signal roles',
      (tester) async {
    final theme = AppTheme.darkTheme;

    expect(theme.scaffoldBackgroundColor, AppColors.backgroundV2);
    expect(theme.colorScheme.primary, AppColors.signal);
    expect(theme.colorScheme.surface, AppColors.surfaceV2);
    expect(theme.colorScheme.secondary, AppColors.textV2Secondary);
    expect(theme.colorScheme.tertiary, AppColors.surfaceV2Active);
    expect(
      theme.bottomNavigationBarTheme.selectedItemColor,
      AppColors.signal,
    );
    expect(
      theme.bottomNavigationBarTheme.unselectedItemColor,
      AppColors.textV2Secondary,
    );
  });

  testWidgets('light theme maps stone surfaces and signal roles',
      (tester) async {
    final theme = AppTheme.lightTheme;

    expect(theme.scaffoldBackgroundColor, AppColors.backgroundV2Light);
    expect(theme.colorScheme.primary, AppColors.signalLight);
    expect(theme.colorScheme.surface, AppColors.surfaceV2Light);
  });
}
