import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Font family constants for premium typography.
class AppFonts {
  static const String primary = 'Outfit';
  static String get display => 'Montserrat';
}

/// Premium color scheme for Zyntro - VIP fitness aesthetic.
class AppColors {
  // Session palette from approved Figma prototypes.
  static const Color sessionNavy900 = Color(0xFF0A0E27);
  static const Color sessionNavy800 = Color(0xFF151B3D);
  static const Color sessionNavy700 = Color(0xFF1E2749);
  static const Color sessionNeonGreen = Color(0xFF39FF14);
  static const Color sessionNeonGreenHover = Color(0xFF2EE00F);
  static const Color sessionGray400 = Color(0xFF8B8B98);
  static const Color sessionMutedText = Color(0xFFA0A0AC);
  static const Color sessionText = Color(0xFFF6F8FF);

  // Primary colors - Neon Cyan
  static const Color primary = Color(0xFF00D9FF);
  static const Color primaryDark = Color(0xFF00A8CC);
  static const Color primaryLight = Color(0xFF5CE1FF);
  static const Color primaryMuted = Color(0xFF0A2A33);
  static const Color primaryGlow = Color(0x4000D9FF);

  // Secondary colors - Coral Red
  static const Color secondary = Color(0xFFFF6B6B);
  static const Color secondaryDark = Color(0xFFE85555);
  static const Color secondaryLight = Color(0xFFFF8E8E);
  static const Color secondaryGlow = Color(0x40FF6B6B);

  // Accent colors
  static const Color accent = Color(0xFFFFD93D);
  static const Color accentDark = Color(0xFFE5C235);
  static const Color accentLight = Color(0xFFFFE566);

  // Premium purple
  static const Color premium = Color(0xFF9D4EDD);
  static const Color premiumDark = Color(0xFF7B2CBF);
  static const Color premiumLight = Color(0xFFB76EF0);
  static const Color premiumGlow = Color(0x409D4EDD);

  // Semantic colors
  static const Color success = Color(0xFF00E676);
  static const Color successDark = Color(0xFF00C853);
  static const Color successGlow = Color(0x4000E676);
  static const Color warning = Color(0xFFFFAB00);
  static const Color error = Color(0xFFFF5252);
  static const Color errorGlow = Color(0x40FF5252);
  static const Color info = Color(0xFF00B0FF);

  // Light mode surface colors
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceSecondaryLight = Color(0xFFF1F5F9);
  static const Color surfaceElevatedLight = Color(0xFFFFFFFF);

  // Light mode text colors
  static const Color textLight = Color(0xFF1E293B);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textTertiaryLight = Color(0xFF94A3B8);
  static const Color textInverseLight = Color(0xFFFFFFFF);

  // Light mode border colors
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderLightSecondary = Color(0xFFF1F5F9);

  // Dark mode surface colors - Deep premium dark
  static const Color backgroundDark = Color(0xFF0A0E1A);
  static const Color surfaceDark = Color(0xFF141B2D);
  static const Color surfaceSecondaryDark = Color(0xFF1F2940);
  static const Color surfaceElevatedDark = Color(0xFF2A3654);

  // Dark mode text colors
  static const Color textDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFFB0BFCE); // Improved contrast
  static const Color textTertiaryDark = Color(0xFF8B9AAF); // Improved contrast
  static const Color textInverseDark = Color(0xFF0A0E1A);

  // Dark mode border colors
  static const Color borderDark = Color(0xFF2A3654);
  static const Color borderDarkSecondary = Color(0xFF3D4F6F);

  // Action color
  static const Color action = Color(0xFFFF6B6B);
  static const Color actionLight = Color(0xFFFF8E8E);
  static const Color actionDark = Color(0xFFE85555);

  // Warm accent colors for streak cards
  static const Color warmBackground = Color(0xFF1A0A0A);
  static const Color warmBorder = Color(0xFFFF6B6B);
  static const Color warmAccent = Color(0xFFFF6B6B);

  // Gradient colors for splash
  static const Color gradientStart = Color(0xFF00D9FF);
  static const Color gradientMiddle = Color(0xFF9D4EDD);
  static const Color gradientEnd = Color(0xFFFF6B6B);

  // Common colors
  static const Color white = Colors.white;
  static const Color text = textLight;

  // Gradient presets
  static const List<Color> primaryGradient = [
    Color(0xFF00D9FF),
    Color(0xFF0099FF),
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFFFF6B6B),
    Color(0xFFFF8E53),
  ];

  static const List<Color> premiumGradient = [
    Color(0xFF9D4EDD),
    Color(0xFF667EEA),
  ];

  static const List<Color> splashGradient = [
    Color(0xFF0A0E1A),
    Color(0xFF141B2D),
    Color(0xFF1F2940),
  ];

  static const List<Color> cardGradient = [
    Color(0xFF1F2940),
    Color(0xFF141B2D),
  ];

  static const List<Color> successGradient = [
    Color(0xFF00E676),
    Color(0xFF00C853),
  ];

  // Additional premium gradients
  static const List<Color> motivationalGradient = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
  ];

  static const List<Color> achievementGradient = [
    Color(0xFF00E676),
    Color(0xFF00D9FF),
  ];

  static const List<Color> streakGradient = [
    Color(0xFFFF6B6B),
    Color(0xFFFF8E53),
    Color(0xFFFFD93D),
  ];

  static const List<Color> sessionAccentGradient = [
    sessionNeonGreen,
    sessionNeonGreenHover,
  ];
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
        titleTextStyle: GoogleFonts.montserrat(
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
          textStyle: GoogleFonts.montserrat(
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
          fontFamily: 'Outfit',
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
        displayLarge: GoogleFonts.montserrat(
          fontSize: AppFontSize.hero,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.montserrat(
          fontSize: AppFontSize.display,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: GoogleFonts.montserrat(
          fontSize: AppFontSize.xxxl,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.montserrat(
          fontSize: AppFontSize.xxl,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: AppFontSize.xl,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: AppFontSize.lg,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: AppFontSize.md,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: AppFontSize.sm,
        ),
        labelLarge: const TextStyle(
          fontFamily: 'Outfit',
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
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.accent,
        surface: AppColors.surfaceDark,
        error: AppColors.error,
        onPrimary: AppColors.textInverseDark,
        onSecondary: AppColors.textInverseLight,
        onSurface: AppColors.textDark,
        onError: AppColors.textInverseLight,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.montserrat(
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
          textStyle: GoogleFonts.montserrat(
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
          fontFamily: 'Outfit',
          color: AppColors.textTertiaryDark,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiaryDark,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.montserrat(
          fontSize: AppFontSize.hero,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.montserrat(
          fontSize: AppFontSize.display,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: GoogleFonts.montserrat(
          fontSize: AppFontSize.xxxl,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.montserrat(
          fontSize: AppFontSize.xxl,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: AppFontSize.xl,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: AppFontSize.lg,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: AppFontSize.md,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: AppFontSize.sm,
        ),
        labelLarge: const TextStyle(
          fontFamily: 'Outfit',
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
    color: AppColors.surfaceDark.withValues(alpha: 0.7),
    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
  );

  static BoxDecoration get elevated => BoxDecoration(
    color: AppColors.surfaceElevatedDark.withValues(alpha: 0.8),
    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
    boxShadow: AppShadows.lg,
  );

  static BoxDecoration primaryBorder({double radius = AppBorderRadius.xl}) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.3),
            AppColors.primary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      );
}
