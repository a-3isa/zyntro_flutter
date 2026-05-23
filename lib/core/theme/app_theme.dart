import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Font family constants for premium typography.
class AppFonts {
  static const String primary = 'Inter';
  static String get display => 'Outfit';
}

/// Premium color scheme for Zyntro - Figma navy and neon-green palette.
class AppColors {
  // Figma navy scale
  static const Color navy900 = Color(0xFF0A0E27);
  static const Color navy800 = Color(0xFF151B3D);
  static const Color navy700 = Color(0xFF1E2749);

  // Figma neon green scale
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonGreenHover = Color(0xFF2EE00F);

  // Figma gray scale
  static const Color gray400 = Color(0xFF8B8B98);
  static const Color gray300 = Color(0xFFA0A0AC);

  // Primary colors - Neon Green
  static const Color primary = neonGreen;
  static const Color primaryDark = neonGreenHover;
  static const Color primaryLight = Color(0xFF6CFF52);
  static const Color primaryMuted = navy700;
  static const Color primaryGlow = Colors.transparent;

  // Secondary colors - Gray
  static const Color secondary = gray400;
  static const Color secondaryDark = gray300;
  static const Color secondaryLight = Color(0xFFC7C7D1);
  static const Color secondaryGlow = Colors.transparent;

  // Accent colors
  static const Color accent = navy700;
  static const Color accentDark = navy800;
  static const Color accentLight = gray300;

  // Premium navy
  static const Color premium = navy800;
  static const Color premiumDark = navy900;
  static const Color premiumLight = navy700;
  static const Color premiumGlow = Colors.transparent;

  // Semantic colors
  static const Color success = Color(0xFF10B981);
  static const Color successDark = Color(0xFF059669);
  static const Color successGlow = Color(0x4010B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorGlow = Color(0x40EF4444);
  static const Color info = Color(0xFF3B82F6);

  // Light mode surface colors
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceSecondaryLight = Color(0xFFF1F5F9);
  static const Color surfaceElevatedLight = Color(0xFFFFFFFF);

  // Light mode text colors
  static const Color textLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);
  static const Color textInverseLight = Color(0xFFFFFFFF);

  // Light mode border colors
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderLightSecondary = Color(0xFFF1F5F9);

  // Dark mode surface colors - Figma navy
  static const Color backgroundDark = navy900;
  static const Color surfaceDark = navy800;
  static const Color surfaceSecondaryDark = navy700;
  static const Color surfaceElevatedDark = Color(0xFF22305B);

  // Dark mode text colors
  static const Color textDark = Colors.white;
  static const Color textSecondaryDark = gray300;
  static const Color textTertiaryDark = gray400;
  static const Color textInverseDark = navy900;

  // Dark mode border colors
  static const Color borderDark = navy700;
  static const Color borderDarkSecondary = Color(0xFF263156);

  // Action color
  static const Color action = neonGreen;
  static const Color actionLight = primaryLight;
  static const Color actionDark = neonGreenHover;

  // Warm accent colors for streak cards
  static const Color warmBackground = navy700;
  static const Color warmBorder = neonGreen;
  static const Color warmAccent = gray300;

  // Gradient colors for splash
  static const Color gradientStart = navy900;
  static const Color gradientMiddle = navy800;
  static const Color gradientEnd = navy700;
  static const Color splashGradientBlue = Color(0xFF061953);
  static const Color splashGradientNavy = Color(0xFF071E31);
  static const Color splashGradientTeal = Color(0xFF06372E);
  static const Color splashGradientGreen = Color(0xFF082F12);

  // Common colors
  static const Color white = Colors.white;
  static const Color text = textLight;

  // Gradient presets
  static const List<Color> primaryGradient = [neonGreen, neonGreenHover];
  static const List<Color> secondaryGradient = [navy700, navy800];
  static const List<Color> premiumGradient = [navy800, navy700];
  static const List<Color> splashGradient = [
    splashGradientBlue,
    splashGradientNavy,
    splashGradientTeal,
    splashGradientGreen,
  ];
  static const List<Color> cardGradient = [navy800, navy700];

  static const List<Color> successGradient = [
    Color(0xFF10B981),
    Color(0xFF34D399),
  ];

  // Additional gradients
  static const List<Color> motivationalGradient = [navy700, neonGreen];
  static const List<Color> achievementGradient = [navy800, neonGreen];
  static const List<Color> streakGradient = [navy700, navy800, neonGreenHover];
}

/// Helper class for creating gradients with common configurations.
class AppGradients {
  static LinearGradient primary({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) =>
      LinearGradient(colors: AppColors.primaryGradient, begin: begin, end: end);

  static LinearGradient secondary({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) => LinearGradient(
    colors: AppColors.secondaryGradient,
    begin: begin,
    end: end,
  );

  static LinearGradient premium({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) =>
      LinearGradient(colors: AppColors.premiumGradient, begin: begin, end: end);

  static LinearGradient motivational({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) => LinearGradient(
    colors: AppColors.motivationalGradient,
    begin: begin,
    end: end,
  );

  static LinearGradient achievement({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) => LinearGradient(
    colors: AppColors.achievementGradient,
    begin: begin,
    end: end,
  );

  static LinearGradient streak({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) =>
      LinearGradient(colors: AppColors.streakGradient, begin: begin, end: end);

  static LinearGradient success({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) =>
      LinearGradient(colors: AppColors.successGradient, begin: begin, end: end);

  static const LinearGradient splashBackground = LinearGradient(
    colors: AppColors.splashGradient,
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    stops: [0.0, 0.34, 0.68, 1.0],
  );

  static LinearGradient card({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) => LinearGradient(colors: AppColors.cardGradient, begin: begin, end: end);
}

/// Spacing constants for consistent layout.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Border radius constants - more rounded for premium feel.
class AppBorderRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double full = 9999;
}

/// Font size constants for typography.
class AppFontSize {
  static const double xs = 12;
  static const double sm = 14;
  static const double md = 16;
  static const double lg = 18;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double display = 40;
  static const double hero = 48;
}

/// Shadow definitions - premium glow effects.
class AppShadows {
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 2), blurRadius: 4),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 12),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x26000000), offset: Offset(0, 8), blurRadius: 24),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(color: Color(0x33000000), offset: Offset(0, 12), blurRadius: 32),
  ];

  // Glow effects for buttons and cards
  static List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: AppColors.primaryGlow,
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> secondaryGlow = [
    BoxShadow(
      color: AppColors.secondaryGlow,
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> premiumGlow = [
    BoxShadow(
      color: AppColors.premiumGlow,
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> successGlow = [
    BoxShadow(
      color: AppColors.successGlow,
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> errorGlow = [
    BoxShadow(
      color: AppColors.errorGlow,
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // Elevation-based shadows for different depths
  static List<BoxShadow> elevation1 = const [
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 1), blurRadius: 3),
  ];

  static List<BoxShadow> elevation2 = const [
    BoxShadow(color: Color(0x0F000000), offset: Offset(0, 3), blurRadius: 6),
  ];

  static List<BoxShadow> elevation3 = const [
    BoxShadow(color: Color(0x14000000), offset: Offset(0, 6), blurRadius: 12),
  ];

  static List<BoxShadow> elevation4 = const [
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 10), blurRadius: 20),
  ];
}

/// Animation durations for micro-interactions.
class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration slower = Duration(milliseconds: 600);
  static const Duration page = Duration(milliseconds: 350);
}

/// Animation curves for premium feel.
class AppCurves {
  static const Curve smooth = Curves.easeInOutCubic;
  static const Curve bounce = Curves.elasticOut;
  static const Curve spring = Curves.easeOutBack;
  static const Curve decelerate = Curves.decelerate;
  static const Curve premium = Curves.easeOutCubic;
}

/// Animation configuration constants for consistent micro-interactions.
class AppAnimations {
  // Duration constants
  static const Duration microInteraction = Duration(milliseconds: 100);
  static const Duration cardHover = Duration(milliseconds: 200);
  static const Duration pageTransition = Duration(milliseconds: 350);
  static const Duration shimmer = Duration(milliseconds: 1500);
  static const Duration pulse = Duration(milliseconds: 1000);
  static const Duration countUp = Duration(milliseconds: 800);

  // Scale transformations
  static const double buttonPressScale = 0.96;
  static const double cardPressScale = 0.98;
  static const double reactionBounceScale = 1.3;
  static const double pulseMinScale = 1.0;
  static const double pulseMaxScale = 1.15;

  // Rotation angles (in radians)
  static const double microRotation = 0.02; // ~1 degree

  // Common curves
  static const Curve defaultCurve = Curves.easeInOutCubic;
  static const Curve springCurve = Curves.elasticOut;
  static const Curve bounceCurve = Curves.easeOutBack;
}

/// App theme configuration.
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppFonts.primary,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.accent,
        surface: AppColors.surfaceLight,
        error: AppColors.error,
        onPrimary: AppColors.textInverseDark,
        onSecondary: AppColors.textInverseLight,
        onSurface: AppColors.textLight,
        onError: AppColors.textInverseLight,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: AppFontSize.lg,
          fontWeight: FontWeight.w600,
          color: AppColors.textLight,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textInverseDark,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: AppFontSize.md,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSecondaryLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        prefixIconColor: AppColors.textSecondaryLight,
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textTertiaryLight,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiaryLight,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(
          fontSize: AppFontSize.hero,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: AppFontSize.display,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: GoogleFonts.outfit(
          fontSize: AppFontSize.xxxl,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: AppFontSize.xxl,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Inter',
          fontSize: AppFontSize.xl,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          fontFamily: 'Inter',
          fontSize: AppFontSize.lg,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: const TextStyle(
          fontFamily: 'Inter',
          fontSize: AppFontSize.md,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'Inter',
          fontSize: AppFontSize.sm,
        ),
        labelLarge: const TextStyle(
          fontFamily: 'Inter',
          fontSize: AppFontSize.md,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppFonts.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonGreen,
        secondary: AppColors.gray400,
        tertiary: AppColors.navy700,
        surface: AppColors.navy800,
        error: AppColors.error,
        onPrimary: AppColors.navy900,
        onSecondary: AppColors.textDark,
        onSurface: AppColors.textDark,
        onError: AppColors.textDark,
      ),
      scaffoldBackgroundColor: AppColors.navy900,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: AppFontSize.lg,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          side: BorderSide(color: AppColors.borderDark.withValues(alpha: 0.5)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textInverseDark,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: AppFontSize.md,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSecondaryDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: BorderSide(
            color: AppColors.borderDark.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        prefixIconColor: AppColors.textSecondaryDark,
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textTertiaryDark,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.neonGreen,
        unselectedItemColor: AppColors.gray400,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(
          fontSize: AppFontSize.hero,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: AppFontSize.display,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: GoogleFonts.outfit(
          fontSize: AppFontSize.xxxl,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: AppFontSize.xxl,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Inter',
          fontSize: AppFontSize.xl,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          fontFamily: 'Inter',
          fontSize: AppFontSize.lg,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: const TextStyle(
          fontFamily: 'Inter',
          fontSize: AppFontSize.md,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'Inter',
          fontSize: AppFontSize.sm,
        ),
        labelLarge: const TextStyle(
          fontFamily: 'Inter',
          fontSize: AppFontSize.md,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Generate a dynamic theme from a seed color using Material 3.
  static ThemeData dynamicTheme(
    Color seedColor, {
    Brightness brightness = Brightness.dark,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    final isDark = brightness == Brightness.dark;
    final baseTheme = isDark ? darkTheme : lightTheme;

    return baseTheme.copyWith(
      colorScheme: colorScheme,
      primaryColor: seedColor,
    );
  }
}

/// Glassmorphism decoration helper.
class GlassDecoration {
  static BoxDecoration get card => BoxDecoration(
    color: AppColors.surfaceDark.withValues(alpha: 0.35),
    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
  );

  static BoxDecoration get elevated => BoxDecoration(
    color: AppColors.surfaceElevatedDark.withValues(alpha: 0.5),
    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    boxShadow: AppShadows.lg,
  );

  static BoxDecoration primaryBorder({double radius = AppBorderRadius.xl}) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      );

  /// To apply a blur effect properly, wrap this container with
  /// ClipRRect and BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20))
}
