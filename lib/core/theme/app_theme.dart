import 'package:flutter/material.dart';
import 'app_text_styles.dart';

/// Font family constants for premium typography.
class AppFonts {
  static const String primary = 'Outfit';
  static const String display = 'Syne';
}

/// Premium color scheme for Zyntro - Figma navy and neon-green palette.
class AppColors {
  // Figma navy scale — legacy, kept for gradientStart/accent/premium; use v2 surface tokens in new code
  static const Color navy900 = Color(0xFF0A0E27);
  static const Color navy800 = Color(0xFF151B3D);
  static const Color navy700 = Color(0xFF1E2749);

  // Figma neon green scale — legacy, kept for compatibility; use accentLime/accentLimeDim in new code
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonGreenHover = Color(0xFF2EE00F);

  // Figma gray scale
  static const Color gray400 = Color(0xFF8B8B98);
  static const Color gray300 = Color(0xFFA0A0AC);

  // Primary colors - Acid Lime (v2)
  static const Color primary = accentLime;
  static const Color primaryDark = accentLimeDim;
  static const Color primaryLight = Color(0xFF6CFF52);
  static const Color primaryMuted = navy700;
  static const Color primaryGlow   = Color(0x33C8FF00); // lime @ 20%

  // Secondary colors - Gray
  static const Color secondary = gray400;
  static const Color secondaryDark = gray300;
  static const Color secondaryLight = Color(0xFFC7C7D1);
  static const Color secondaryGlow = Color(0x1A888888); // grey @ 10%

  // Accent colors
  static const Color accent = navy700;
  static const Color accentDark = navy800;
  static const Color accentLight = gray300;

  // Premium navy
  static const Color premium = navy800;
  static const Color premiumDark = navy900;
  static const Color premiumLight = navy700;
  static const Color premiumGlow   = Color(0x1AC8FF00); // lime @ 10%

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

  // Dark mode surface colors — aliased to v2 true-black tokens
  static const Color backgroundDark = backgroundV2;
  static const Color surfaceDark = surfaceV2;
  static const Color surfaceSecondaryDark = surfaceV2Elevated;
  static const Color surfaceElevatedDark = surfaceV2Active;

  // Dark mode text colors — aliased to v2 tokens
  static const Color textDark = textV2Primary;
  static const Color textSecondaryDark = textV2Secondary;
  static const Color textTertiaryDark = textV2Tertiary;
  static const Color textInverseDark = backgroundV2;

  // Dark mode border colors — aliased to v2 tokens
  static const Color borderDark = surfaceV2Active;
  static const Color borderDarkSecondary = surfaceV2Elevated;

  // Action color
  static const Color action = accentLime;
  static const Color actionLight = primaryLight;
  static const Color actionDark = accentLimeDim;

  // Warm accent colors for streak cards
  static const Color warmBackground = surfaceV2Elevated;
  static const Color warmBorder = accentLime;
  static const Color warmAccent = textV2Secondary;

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

  // Gradient presets (v2 — true-black + acid-lime)
  static const List<Color> primaryGradient = [accentLime, accentLimeDim];
  static const List<Color> secondaryGradient = [surfaceV2Elevated, surfaceV2];
  static const List<Color> premiumGradient = [surfaceV2, surfaceV2Elevated];
  static const List<Color> splashGradient = [
    backgroundV2,
    surfaceV2,
    surfaceV2Elevated,
    surfaceV2Active,
  ];
  static const List<Color> cardGradient = [surfaceV2, surfaceV2Elevated];

  static const List<Color> successGradient = [
    Color(0xFF10B981),
    Color(0xFF34D399),
  ];

  // Additional gradients (v2)
  static const List<Color> motivationalGradient = [surfaceV2Elevated, accentLime];
  static const List<Color> achievementGradient = [surfaceV2, accentLime];
  static const List<Color> streakGradient = [surfaceV2Elevated, surfaceV2, accentLimeDim];

  // ── v2 Design tokens (true-black + acid-lime) ──────────────────────────────
  // Dark mode surfaces
  static const Color backgroundV2 = Color(0xFF080808);
  static const Color surfaceV2 = Color(0xFF111111);
  static const Color surfaceV2Elevated = Color(0xFF1C1C1C);
  static const Color surfaceV2Active = Color(0xFF242424);

  // Accent SEED values (the default neon green). These are `const` and exist
  // only as the fallback/seed for [userAccent]. DO NOT use accentLime directly
  // in UI — use [userAccent]/[userAccentDim] so the color follows the signed-in
  // user's choice. Putting a const color where a runtime value is needed is the
  // exact trap that made per-user theming hard; userAccent avoids it.
  static const Color accentLime = Color(0xFFC8FF00);
  static const Color accentLimeDim = Color(0xFFA6D400);

  // ── Per-user dynamic accent ────────────────────────────────────────────────
  // Mutable runtime accent, set from the color the user picks during profile
  // setup (defaults to the neon green). Non-const widget code reads these so
  // the whole app takes on the user's color. Use [setAccent] to update.
  static Color userAccent = accentLime;
  static Color userAccentDim = accentLimeDim;

  /// Apply a user's chosen accent color app-wide. [dim] defaults to a slightly
  /// darker shade for pressed/secondary states.
  static void setAccent(Color color, {Color? dim}) {
    userAccent = color;
    userAccentDim = dim ?? _darken(color, 0.16);
  }

  /// Reset the accent back to the default neon green (e.g. on sign-out).
  static void resetAccent() {
    userAccent = accentLime;
    userAccentDim = accentLimeDim;
  }

  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  // Dark mode text
  static const Color textV2Primary = Color(0xFFFFFFFF);
  static const Color textV2Secondary = Color(0xFF888888);
  static const Color textV2Tertiary = Color(0xFF444444);

  // Semantic (same in both modes)
  static const Color errorV2 = Color(0xFFFF4D4D);
  static const Color okV2 = Color(0xFF00D68F);
  static const Color warnV2 = Color(0xFFFF8C00);
  static const Color warnV2Glow = Color(0x33FF8C00); // warn @ 20%
  static const Color accentLimeGlowFaint = Color(0x10C8FF00); // lime @ 6%

  // Light mode surfaces
  static const Color backgroundV2Light = Color(0xFFF8F8F8);
  static const Color surfaceV2Light = Color(0xFFFFFFFF);
  static const Color surfaceV2ElevatedLight = Color(0xFFF2F2F2);
  static const Color surfaceV2ActiveLight = Color(0xFFE8E8E8);

  // Light mode accent
  static const Color accentLimeLight = Color(0xFF8AB000);
  static const Color accentLimeDimLight = Color(0xFF6E8C00);

  // Light mode text
  static const Color textV2PrimaryLight = Color(0xFF0A0A0A);
  static const Color textV2SecondaryLight = Color(0xFF555555);
  static const Color textV2TertiaryLight = Color(0xFFBBBBBB);

  // Workout type accent colors
  static const Map<String, Color> typeColors = {
    'gym': Color(0xFFC8FF00),
    'cardio': Color(0xFF38BDF8),
    'hiit': Color(0xFFFF8C00),
    'cycling': Color(0xFFA78BFA),
    'yoga': Color(0xFF34D399),
    'swimming': Color(0xFF22D3EE),
  };

  static Color typeColor(String type) => typeColors[type] ?? accentLime;
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
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 24;
  static const double xxl  = 32;
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
    BoxShadow(color: Color(0x0AC8FF00), offset: Offset(0, 2), blurRadius: 4),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x12C8FF00), offset: Offset(0, 4), blurRadius: 12),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x18C8FF00), offset: Offset(0, 8), blurRadius: 24),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(color: Color(0x20C8FF00), offset: Offset(0, 12), blurRadius: 32),
  ];

  // Glow effects for buttons and cards
  static List<BoxShadow> primaryGlow = [
    BoxShadow(color: AppColors.primaryGlow, blurRadius: 20, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> premiumGlow = [
    BoxShadow(color: AppColors.premiumGlow, blurRadius: 20, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> secondaryGlow = [
    BoxShadow(color: AppColors.secondaryGlow, blurRadius: 20, offset: const Offset(0, 8)),
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
  static const Curve premium    = Cubic(0.23, 1.00, 0.32, 1.00);
  static const Curve smooth     = Cubic(0.77, 0.00, 0.175, 1.00);
  static const Curve spring     = Cubic(0.34, 1.56, 0.64, 1.00);
  static const Curve decelerate = Cubic(0.00, 0.00, 0.20, 1.00);
  static const Curve press      = Cubic(0.23, 1.00, 0.32, 1.00);
  static const Curve bounce     = Cubic(0.34, 1.56, 0.64, 1.00);
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
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentLimeLight,
        secondary: AppColors.textV2SecondaryLight,
        tertiary: AppColors.surfaceV2ActiveLight,
        surface: AppColors.surfaceV2Light,
        error: AppColors.errorV2,
        onPrimary: AppColors.textV2PrimaryLight,
        onSecondary: AppColors.textV2PrimaryLight,
        onSurface: AppColors.textV2PrimaryLight,
        onError: AppColors.textV2PrimaryLight,
      ),
      scaffoldBackgroundColor: AppColors.backgroundV2Light,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundV2Light,
        foregroundColor: AppColors.textV2PrimaryLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.h5.copyWith(color: AppColors.textV2PrimaryLight),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceV2Light,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentLimeLight,
          foregroundColor: AppColors.textV2PrimaryLight,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
          ),
          textStyle: AppTextStyles.label,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceV2ElevatedLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.surfaceV2ActiveLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(
            color: AppColors.accentLimeLight,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        prefixIconColor: AppColors.textV2SecondaryLight,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textV2TertiaryLight),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.backgroundV2Light,
        selectedItemColor: AppColors.accentLimeLight,
        unselectedItemColor: AppColors.textV2SecondaryLight,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceV2ActiveLight,
        thickness: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.textV2PrimaryLight
              : AppColors.textV2TertiaryLight,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.accentLimeLight
              : AppColors.surfaceV2ActiveLight,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.display.copyWith(color: AppColors.textV2PrimaryLight),
        displayMedium: AppTextStyles.h1.copyWith(color: AppColors.textV2PrimaryLight),
        headlineLarge: AppTextStyles.h2.copyWith(color: AppColors.textV2PrimaryLight),
        headlineMedium: AppTextStyles.h3.copyWith(color: AppColors.textV2PrimaryLight),
        titleLarge: AppTextStyles.h4.copyWith(color: AppColors.textV2PrimaryLight),
        titleMedium: AppTextStyles.h5.copyWith(color: AppColors.textV2PrimaryLight),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: AppColors.textV2PrimaryLight),
        bodyMedium: AppTextStyles.body.copyWith(color: AppColors.textV2SecondaryLight),
        labelLarge: AppTextStyles.label.copyWith(color: AppColors.textV2PrimaryLight),
        labelSmall: AppTextStyles.caption.copyWith(color: AppColors.textV2SecondaryLight),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppFonts.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentLime,
        secondary: AppColors.textV2Secondary,
        tertiary: AppColors.surfaceV2Active,
        surface: AppColors.surfaceV2,
        error: AppColors.errorV2,
        onPrimary: AppColors.backgroundV2,
        onSecondary: AppColors.textV2Primary,
        onSurface: AppColors.textV2Primary,
        onError: AppColors.textV2Primary,
      ),
      scaffoldBackgroundColor: AppColors.backgroundV2,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textV2Primary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.h5.copyWith(color: AppColors.textV2Primary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceV2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentLime,
          foregroundColor: AppColors.backgroundV2,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
          ),
          textStyle: AppTextStyles.label,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceV2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.surfaceV2Active),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(color: AppColors.accentLime, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        prefixIconColor: AppColors.textV2Secondary,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textV2Tertiary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.accentLime,
        unselectedItemColor: AppColors.textV2Secondary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceV2,
        thickness: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.backgroundV2
              : AppColors.textV2Tertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.accentLime
              : AppColors.surfaceV2Active,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.display.copyWith(color: AppColors.textV2Primary),
        displayMedium: AppTextStyles.h1.copyWith(color: AppColors.textV2Primary),
        headlineLarge: AppTextStyles.h2.copyWith(color: AppColors.textV2Primary),
        headlineMedium: AppTextStyles.h3.copyWith(color: AppColors.textV2Primary),
        titleLarge: AppTextStyles.h4.copyWith(color: AppColors.textV2Primary),
        titleMedium: AppTextStyles.h5.copyWith(color: AppColors.textV2Primary),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: AppColors.textV2Primary),
        bodyMedium: AppTextStyles.body.copyWith(color: AppColors.textV2Secondary),
        labelLarge: AppTextStyles.label.copyWith(color: AppColors.textV2Primary),
        labelSmall: AppTextStyles.caption.copyWith(color: AppColors.textV2Secondary),
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
