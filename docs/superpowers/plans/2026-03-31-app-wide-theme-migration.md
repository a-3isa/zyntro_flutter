# App-Wide Theme Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the approved Figma navy and neon-green theme across the Flutter app while removing icon glow treatments and keeping all logic and feature behavior unchanged.

**Architecture:** Migrate the visual system in layers: first remap the global theme tokens in `app_theme.dart`, then retheme shared UI primitives so most screens inherit the new look, then clean up high-traffic widgets and screens that still hard-code legacy purple or glow styling. Protect the work with palette contract tests, shared-widget source contracts, and existing behavior tests for session flow.

**Tech Stack:** Flutter, Dart, flutter_test, Riverpod, GoRouter

---

## File Structure

- `lib/core/theme/app_theme.dart`
  Central app palette, gradients, shadow tokens, `ThemeData`, and `ColorScheme`.

- `test/core/theme/app_theme_palette_contract_test.dart`
  Runtime contract coverage for the approved Figma palette and the dark theme mapping.

- `lib/widgets/premium_effects.dart`
  Shared glow, border, and gradient helpers that currently default to cyan and purple glows.

- `lib/widgets/premium_animations.dart`
  Shared animation helpers with legacy cyan and purple gradient defaults.

- `lib/widgets/zyntro_button.dart`
  Shared button styling, gradients, foreground colors, and glow-based box shadows.

- `lib/widgets/zyntro_card.dart`
  Shared card surfaces, borders, and glow-enabled elevation treatment.

- `test/widgets/visual_primitives_source_contract_test.dart`
  Source-level contract coverage to ensure shared primitives no longer ship legacy glow defaults.

- `lib/features/main/presentation/main_shell.dart`
  Floating bottom navigation pill and central workout FAB styling.

- `lib/widgets/reaction_buttons.dart`
  Selected reaction state that currently adds pulsing glow.

- `test/features/main/presentation/main_shell_theme_test.dart`
  Widget smoke coverage for the active and inactive navigation icon colors.

- `test/widgets/reaction_buttons_theme_test.dart`
  Widget coverage to ensure selected reactions render without `PulsingGlow`.

- `lib/features/session/presentation/start_session_page.dart`
  Session entry screen with hard-coded `PulsingGlow`, premium gradients, and glow-heavy selection states.

- `lib/features/auth/presentation/onboarding_page.dart`
  Auth onboarding hero surfaces that still use premium gradients and glow wrappers.

- `lib/features/auth/presentation/login_page.dart`
  Login CTA and logo styling that still uses `GlowContainer`.

- `lib/features/auth/presentation/signup_page.dart`
  Signup CTA and hero styling that still uses `GlowContainer`.

- `lib/features/auth/presentation/forgot_password_page.dart`
  Reset-password icon and success-state glow wrappers.

- `lib/features/profile/presentation/profile_page.dart`
  Avatar and streak sections with explicit glow wrappers.

- `lib/features/profile/presentation/edit_profile_page.dart`
  Avatar selector and save affordances with pulsing glow.

- `lib/features/session/presentation/session_page.dart`
  Session dashboard tiles still wrapped in `GlowContainer`.

- `lib/features/session/presentation/recap_page.dart`
  Celebration header with glow wrapper.

- `lib/features/settings/presentation/settings_page.dart`
  Logout affordance wrapped in `GlowContainer`.

- `lib/widgets/streak_card.dart`
  Streak badge and flame icon glow styling.

- `test/app/app_visual_source_contract_test.dart`
  Source contract ensuring targeted screens no longer use `GlowContainer`, `PulsingGlow`, or `AppColors.premiumGradient`.

- `test/features/session/presentation/start_session_page_test.dart`
  Existing behavior test that protects gym versus non-gym flow while the visuals change.

### Task 1: Add The Global Figma Palette Contract And Remap Theme Tokens

**Files:**
- Create: `test/core/theme/app_theme_palette_contract_test.dart`
- Modify: `lib/core/theme/app_theme.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';

void main() {
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_theme_palette_contract_test.dart`
Expected: FAIL with errors such as `Getter not found: 'navy900'` and palette values not matching the new contract.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/theme/app_theme.dart
class AppColors {
  static const Color navy900 = Color(0xFF0A0E27);
  static const Color navy800 = Color(0xFF151B3D);
  static const Color navy700 = Color(0xFF1E2749);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonGreenHover = Color(0xFF2EE00F);
  static const Color gray400 = Color(0xFF8B8B98);
  static const Color gray300 = Color(0xFFA0A0AC);

  static const Color primary = neonGreen;
  static const Color primaryDark = neonGreenHover;
  static const Color primaryLight = Color(0xFF6CFF52);
  static const Color primaryMuted = navy700;
  static const Color primaryGlow = Colors.transparent;

  static const Color secondary = gray400;
  static const Color secondaryDark = gray300;
  static const Color secondaryLight = Color(0xFFC7C7D1);
  static const Color secondaryGlow = Colors.transparent;

  static const Color accent = navy700;
  static const Color accentDark = navy800;
  static const Color accentLight = gray300;

  static const Color premium = navy800;
  static const Color premiumDark = navy900;
  static const Color premiumLight = navy700;
  static const Color premiumGlow = Colors.transparent;

  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceSecondaryLight = Color(0xFFEAEEF5);
  static const Color surfaceElevatedLight = Colors.white;

  static const Color backgroundDark = navy900;
  static const Color surfaceDark = navy800;
  static const Color surfaceSecondaryDark = navy700;
  static const Color surfaceElevatedDark = Color(0xFF22305B);

  static const Color textDark = Colors.white;
  static const Color textSecondaryDark = gray300;
  static const Color textTertiaryDark = gray400;

  static const Color borderDark = navy700;
  static const Color borderDarkSecondary = Color(0xFF263156);

  static const Color action = neonGreen;
  static const Color actionLight = primaryLight;
  static const Color actionDark = neonGreenHover;

  static const List<Color> primaryGradient = [neonGreen, neonGreenHover];
  static const List<Color> secondaryGradient = [navy700, navy800];
  static const List<Color> premiumGradient = [navy800, navy700];
  static const List<Color> cardGradient = [navy800, navy700];
  static const List<Color> motivationalGradient = [navy700, neonGreen];
  static const List<Color> achievementGradient = [navy800, neonGreen];
  static const List<Color> streakGradient = [navy700, navy800, neonGreenHover];
}

static ThemeData get darkTheme {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.neonGreen,
      secondary: AppColors.gray400,
      tertiary: AppColors.navy700,
      surface: AppColors.navy800,
      onPrimary: AppColors.navy900,
      onSecondary: AppColors.textDark,
      onSurface: AppColors.textDark,
      error: AppColors.error,
      onError: AppColors.textDark,
    ),
    scaffoldBackgroundColor: AppColors.navy900,
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.navy800,
      selectedItemColor: AppColors.neonGreen,
      unselectedItemColor: AppColors.gray400,
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/app_theme_palette_contract_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_theme.dart test/core/theme/app_theme_palette_contract_test.dart
git commit -m "feat: migrate app theme tokens to figma palette"
```

### Task 2: Retheme Shared Visual Primitives And Neutralize Glow Defaults

**Files:**
- Modify: `lib/widgets/premium_effects.dart`
- Modify: `lib/widgets/premium_animations.dart`
- Modify: `lib/widgets/zyntro_button.dart`
- Modify: `lib/widgets/zyntro_card.dart`
- Create: `test/widgets/visual_primitives_source_contract_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';
import 'package:zyntro_flutter/widgets/premium_effects.dart';

void main() {
  test('glow helpers default to figma-aligned non-glow styling', () {
    const glow = GlowContainer(child: SizedBox());
    const pulse = PulsingGlow(child: SizedBox());
    const text = GradientText(text: 'Train');
    const border = GradientBorder(child: SizedBox());

    expect(glow.glowColor, Colors.transparent);
    expect(glow.blurRadius, 0);
    expect(pulse.glowColor, Colors.transparent);
    expect(pulse.maxRadius, 0);
    expect(text.colors, const [AppColors.textDark, AppColors.neonGreen]);
    expect(border.gradientColors, AppColors.primaryGradient);
  });

  test('shared primitives no longer reference legacy cyan or purple defaults', () {
    final effects = File('lib/widgets/premium_effects.dart').readAsStringSync();
    final animations = File('lib/widgets/premium_animations.dart').readAsStringSync();
    final button = File('lib/widgets/zyntro_button.dart').readAsStringSync();

    expect(effects.contains('0xFF00D9FF'), isFalse);
    expect(effects.contains('0xFF9D4EDD'), isFalse);
    expect(animations.contains('0xFF00D9FF'), isFalse);
    expect(animations.contains('0xFF9D4EDD'), isFalse);
    expect(button.contains('AppColors.primaryGlow.withValues'), isFalse);
    expect(button.contains('AppColors.secondaryGlow.withValues'), isFalse);
    expect(button.contains('AppColors.premiumGlow.withValues'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/visual_primitives_source_contract_test.dart`
Expected: FAIL because the helper defaults still use cyan and purple gradients and `zyntro_button.dart` still references glow-colored shadows.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/widgets/premium_effects.dart
class GlowContainer extends StatelessWidget {
  const GlowContainer({
    super.key,
    required this.child,
    this.glowColor = Colors.transparent,
    this.blurRadius = 0,
    this.spreadRadius = 0,
    this.borderRadius,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final boxShadows = glowColor == Colors.transparent || blurRadius == 0
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: glowColor,
              blurRadius: blurRadius,
              spreadRadius: spreadRadius,
            ),
          ];

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(AppBorderRadius.xl),
        boxShadow: boxShadows,
      ),
      child: child,
    );
  }
}

class PulsingGlow extends StatefulWidget {
  const PulsingGlow({
    super.key,
    required this.child,
    this.glowColor = Colors.transparent,
    this.minRadius = 0,
    this.maxRadius = 0,
    this.duration = const Duration(milliseconds: 1500),
  });
}

class GradientBorder extends StatelessWidget {
  const GradientBorder({
    super.key,
    required this.child,
    this.gradientColors = AppColors.primaryGradient,
    this.borderWidth = 2,
    this.borderRadius,
    this.padding,
  });
}

class GradientText extends StatelessWidget {
  const GradientText({
    super.key,
    required this.text,
    this.style,
    this.colors = const [AppColors.textDark, AppColors.neonGreen],
    this.textAlign,
  });
}

// lib/widgets/premium_animations.dart
class GradientBorderAnimation extends StatefulWidget {
  const GradientBorderAnimation({
    super.key,
    required this.child,
    this.gradientColors = AppColors.primaryGradient,
    this.borderWidth = 2,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.duration = const Duration(seconds: 3),
    this.enabled = true,
  });
}

// lib/widgets/zyntro_button.dart
List<BoxShadow>? _getBoxShadow() {
  if (widget.variant == ZyntroButtonVariant.outline ||
      widget.variant == ZyntroButtonVariant.ghost) {
    return null;
  }

  return const [
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}

List<Color> _getGradientColors() {
  switch (widget.variant) {
    case ZyntroButtonVariant.primary:
      return AppColors.primaryGradient;
    case ZyntroButtonVariant.secondary:
      return AppColors.secondaryGradient;
    case ZyntroButtonVariant.premium:
      return AppColors.primaryGradient;
    case ZyntroButtonVariant.destructive:
      return [AppColors.error, AppColors.error.withValues(alpha: 0.85)];
    case ZyntroButtonVariant.outline:
    case ZyntroButtonVariant.ghost:
      return [Colors.transparent, Colors.transparent];
  }
}

// lib/widgets/zyntro_card.dart
if (widget.showGlow) {
  boxShadow = const [
    BoxShadow(
      color: Color(0x22000000),
      blurRadius: 14,
      offset: Offset(0, 6),
    ),
  ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/visual_primitives_source_contract_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/premium_effects.dart lib/widgets/premium_animations.dart lib/widgets/zyntro_button.dart lib/widgets/zyntro_card.dart test/widgets/visual_primitives_source_contract_test.dart
git commit -m "feat: retheme shared visual primitives"
```

### Task 3: Retheme The Floating Navigation And Remove Reaction Glow

**Files:**
- Modify: `lib/features/main/presentation/main_shell.dart`
- Modify: `lib/widgets/reaction_buttons.dart`
- Create: `test/features/main/presentation/main_shell_theme_test.dart`
- Create: `test/widgets/reaction_buttons_theme_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';
import 'package:zyntro_flutter/features/main/presentation/main_shell.dart';
import 'package:zyntro_flutter/widgets/premium_effects.dart';
import 'package:zyntro_flutter/widgets/reaction_buttons.dart';

void main() {
  testWidgets('main shell uses figma active and inactive nav colors', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MainShell()),
      ),
    );

    await tester.pumpAndSettle();

    final activeHome = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
    final inactiveSocial = tester.widget<Icon>(find.byIcon(Icons.people_outline));

    expect(activeHome.color, AppColors.neonGreen);
    expect(inactiveSocial.color, AppColors.gray400);
  });

  testWidgets('selected reaction does not render pulsing glow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: ReactionButtons(
            postId: 'post-1',
            currentReaction: ReactionType.fire,
            reactionCounts: const {ReactionType.fire: 2},
            onReactionTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(PulsingGlow), findsNothing);
    expect(find.byType(ReactionButtons), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/main/presentation/main_shell_theme_test.dart test/widgets/reaction_buttons_theme_test.dart`
Expected: FAIL because the nav still uses legacy token mapping and selected reactions still wrap the button with `PulsingGlow`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/main/presentation/main_shell.dart
decoration: BoxDecoration(
  color: AppColors.navy800.withValues(alpha: 0.92),
  borderRadius: BorderRadius.circular(36),
  border: Border.all(
    color: AppColors.navy700.withValues(alpha: 0.9),
    width: 1,
  ),
  boxShadow: const [
    BoxShadow(
      color: Color(0x26000000),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ],
),

color: isActive ? AppColors.neonGreen : AppColors.gray400,

decoration: const BoxDecoration(
  gradient: LinearGradient(
    colors: AppColors.primaryGradient,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  shape: BoxShape.circle,
  boxShadow: [
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ],
),
child: const Icon(
  Icons.fitness_center,
  color: AppColors.navy900,
  size: 26,
),

// lib/widgets/reaction_buttons.dart
decoration: BoxDecoration(
  gradient: isSelected
      ? LinearGradient(
          colors: [
            AppColors.neonGreen.withValues(alpha: 0.14),
            AppColors.neonGreen.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : null,
  color: isSelected ? null : Colors.transparent,
  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
  border: Border.all(
    color: isSelected ? AppColors.neonGreen : AppColors.gray400.withValues(alpha: 0.3),
    width: isSelected ? 2 : 1,
  ),
),

// Remove the PulsingGlow wrapper entirely.
return Semantics(
  label: '$label reaction${count > 0 ? ', $count reactions' : ''}',
  button: true,
  selected: isSelected,
  child: button,
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/main/presentation/main_shell_theme_test.dart test/widgets/reaction_buttons_theme_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/main/presentation/main_shell.dart lib/widgets/reaction_buttons.dart test/features/main/presentation/main_shell_theme_test.dart test/widgets/reaction_buttons_theme_test.dart
git commit -m "feat: retheme navigation and reaction states"
```

### Task 4: Remove Hard-Coded Glow Wrappers And Legacy Premium Gradients From High-Traffic Screens

**Files:**
- Modify: `lib/features/session/presentation/start_session_page.dart`
- Modify: `lib/features/auth/presentation/onboarding_page.dart`
- Modify: `lib/features/auth/presentation/login_page.dart`
- Modify: `lib/features/auth/presentation/signup_page.dart`
- Modify: `lib/features/auth/presentation/forgot_password_page.dart`
- Modify: `lib/features/profile/presentation/profile_page.dart`
- Modify: `lib/features/profile/presentation/edit_profile_page.dart`
- Modify: `lib/features/session/presentation/session_page.dart`
- Modify: `lib/features/session/presentation/recap_page.dart`
- Modify: `lib/features/settings/presentation/settings_page.dart`
- Modify: `lib/widgets/streak_card.dart`
- Create: `test/app/app_visual_source_contract_test.dart`
- Reuse: `test/features/session/presentation/start_session_page_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('targeted screens no longer use glow wrappers or premium gradients', () {
    const files = [
      'lib/features/session/presentation/start_session_page.dart',
      'lib/features/auth/presentation/onboarding_page.dart',
      'lib/features/auth/presentation/login_page.dart',
      'lib/features/auth/presentation/signup_page.dart',
      'lib/features/auth/presentation/forgot_password_page.dart',
      'lib/features/profile/presentation/profile_page.dart',
      'lib/features/profile/presentation/edit_profile_page.dart',
      'lib/features/session/presentation/session_page.dart',
      'lib/features/session/presentation/recap_page.dart',
      'lib/features/settings/presentation/settings_page.dart',
      'lib/widgets/streak_card.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source.contains('GlowContainer('), isFalse, reason: '$path still uses GlowContainer');
      expect(source.contains('PulsingGlow('), isFalse, reason: '$path still uses PulsingGlow');
      expect(source.contains('AppColors.premiumGradient'), isFalse, reason: '$path still uses AppColors.premiumGradient');
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app/app_visual_source_contract_test.dart`
Expected: FAIL because these files still contain `GlowContainer`, `PulsingGlow`, and legacy premium-gradient usage.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/session/presentation/start_session_page.dart
List<Color> _getCategoryGradient(String category) {
  switch (category) {
    case 'cardio':
      return AppColors.secondaryGradient;
    case 'strength':
      return AppColors.primaryGradient;
    case 'flexibility':
      return AppColors.successGradient;
    case 'mixed':
      return AppColors.cardGradient;
    default:
      return [AppColors.textSecondaryDark, AppColors.textTertiaryDark];
  }
}

// Remove the PulsingGlow wrapper around the start button and keep the button direct.
ZyntroButton(
  title: _selectedFriends.isEmpty
      ? 'Start ${_selectedType.displayName} Session'
      : 'Start with ${_selectedFriends.length + 1} athletes',
  fullWidth: true,
  size: ZyntroButtonSize.lg,
  variant: ZyntroButtonVariant.primary,
  loading: _isLoading,
  rightIcon: const Icon(Icons.bolt_rounded),
  onPressed: _isLoading ? null : () {
    HapticManager.heavy();
    _handleStartSession();
  },
),

// lib/features/auth/presentation/onboarding_page.dart
gradientColors: AppColors.cardGradient,

// lib/features/auth/presentation/login_page.dart
// lib/features/auth/presentation/signup_page.dart
// lib/features/auth/presentation/forgot_password_page.dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AppColors.surfaceSecondaryDark.withValues(alpha: 0.55),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.65)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x22000000),
        blurRadius: 12,
        offset: Offset(0, 6),
      ),
    ],
  ),
  child: child,
),

// lib/features/profile/presentation/profile_page.dart
// lib/features/profile/presentation/edit_profile_page.dart
Container(
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(color: AppColors.neonGreen, width: 2),
    boxShadow: const [
      BoxShadow(
        color: Color(0x22000000),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  ),
  child: avatar,
),

// lib/features/session/presentation/session_page.dart
// lib/features/session/presentation/recap_page.dart
ZyntroCard(
  variant: ZyntroCardVariant.elevated,
  backgroundColor: AppColors.surfaceSecondaryDark.withValues(alpha: 0.7),
  child: child,
),

// lib/features/settings/presentation/settings_page.dart
Container(
  decoration: BoxDecoration(
    color: AppColors.surfaceSecondaryDark.withValues(alpha: 0.5),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
  ),
  child: child,
),

// lib/widgets/streak_card.dart
Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: AppColors.neonGreen.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.neonGreen.withValues(alpha: 0.35)),
  ),
  child: const Icon(
    Icons.local_fire_department,
    color: AppColors.neonGreen,
  ),
),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/app/app_visual_source_contract_test.dart test/features/session/presentation/start_session_page_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/session/presentation/start_session_page.dart lib/features/auth/presentation/onboarding_page.dart lib/features/auth/presentation/login_page.dart lib/features/auth/presentation/signup_page.dart lib/features/auth/presentation/forgot_password_page.dart lib/features/profile/presentation/profile_page.dart lib/features/profile/presentation/edit_profile_page.dart lib/features/session/presentation/session_page.dart lib/features/session/presentation/recap_page.dart lib/features/settings/presentation/settings_page.dart lib/widgets/streak_card.dart test/app/app_visual_source_contract_test.dart
git commit -m "feat: remove legacy glow styling from app screens"
```

## Final Verification

Run:

```bash
flutter test test/core/theme/app_theme_palette_contract_test.dart
flutter test test/widgets/visual_primitives_source_contract_test.dart
flutter test test/features/main/presentation/main_shell_theme_test.dart
flutter test test/widgets/reaction_buttons_theme_test.dart
flutter test test/app/app_visual_source_contract_test.dart
flutter test test/features/session/presentation/start_session_page_test.dart
flutter analyze lib/core/theme/app_theme.dart lib/widgets/premium_effects.dart lib/widgets/premium_animations.dart lib/widgets/zyntro_button.dart lib/widgets/zyntro_card.dart lib/widgets/reaction_buttons.dart lib/features/main/presentation/main_shell.dart lib/features/session/presentation/start_session_page.dart lib/features/auth/presentation/onboarding_page.dart lib/features/auth/presentation/login_page.dart lib/features/auth/presentation/signup_page.dart lib/features/auth/presentation/forgot_password_page.dart lib/features/profile/presentation/profile_page.dart lib/features/profile/presentation/edit_profile_page.dart lib/features/session/presentation/session_page.dart lib/features/session/presentation/recap_page.dart lib/features/settings/presentation/settings_page.dart lib/widgets/streak_card.dart
```

Expected:

- all new contract and widget tests pass
- the existing session start behavior test still passes
- analyzer reports no new issues in the touched theme and screen files

Manual QA checklist:

1. Open the feed, session, social, profile, auth, notifications, and settings surfaces and confirm the background stack is navy rather than black or purple.
2. Confirm the main workout FAB and primary CTA buttons use neon green with dark foreground text.
3. Confirm inactive icons render muted gray and active icons render neon green.
4. Confirm there are no colored glow halos around nav icons, action icons, streak icons, or auth CTA surfaces.
5. Confirm the gym and non-gym session start flows still navigate exactly as before.
6. Spot-check login, signup, forgot-password, profile, session recap, and settings logout surfaces for contrast and readability.
