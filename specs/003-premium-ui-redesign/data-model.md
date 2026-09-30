# Design Token Model: Premium UI/UX Redesign

**Branch**: `003-premium-ui-redesign`
**Date**: 2026-05-26

This document defines the canonical design tokens and component specs that this feature introduces or modifies.

---

## 1. AppTextStyles — New Class

**File**: `lib/core/theme/app_text_styles.dart`

### Type Scale

| Getter | Font | Size (sp) | Weight | Letter-spacing | Line-height | Use |
|--------|------|-----------|--------|----------------|-------------|-----|
| `display` | Syne | 48 | w700 | −0.5 | 1.10 | Wordmark, hero headings |
| `h1` | Syne | 40 | w700 | −0.3 | 1.15 | Screen-level page titles |
| `h2` | Syne | 32 | w600 | 0 | 1.20 | Section titles |
| `h3` | Syne | 24 | w600 | 0 | 1.25 | Card headings, modal titles |
| `bodyLarge` | Outfit | 16 | w500 | 0 | 1.50 | Prominent body copy, step labels |
| `body` | Outfit | 14 | w400 | 0 | 1.50 | Standard body copy, descriptions |
| `label` | Outfit | 14 | w600 | 0.1 | 1.20 | Button labels, tab labels, chips |
| `caption` | Outfit | 12 | w400 | 0.2 | 1.40 | Timestamps, helper text, metadata |

### Colour argument
Each getter is a `TextStyle` with no colour specified at definition time — colour is set at the call site using `.copyWith(color: AppColors.textV2Primary)` or equivalent. This keeps the class colour-agnostic and reusable for both light and dark modes.

### textScaleFactor
Capping is NOT handled in AppTextStyles. It is applied once at `MaterialApp.builder` via `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child)`.

---

## 2. AppColors — Token Alias Updates

Existing constants are not deleted. The following alias assignments in `AppColors` are updated to point to v2 tokens:

| Alias | Old value | New value |
|-------|-----------|-----------|
| `AppColors.primary` | `neonGreen` (#39FF14) | `accentLime` (#C8FF00) |
| `AppColors.primaryDark` | `neonGreenHover` (#2EE00F) | `accentLimeDim` (#A6D400) |
| `AppColors.action` | `neonGreen` | `accentLime` |
| `AppColors.actionDark` | `neonGreenHover` | `accentLimeDim` |
| `AppColors.warmBackground` | `navy700` (#1E2749) | `surfaceV2Elevated` (#1C1C1C) |
| `AppColors.warmBorder` | `neonGreen` | `accentLime` |
| `AppColors.warmAccent` | `gray300` | `textV2Secondary` (#888888) |

### Gradient preset updates

| Preset | Old colours | New colours |
|--------|-------------|-------------|
| `primaryGradient` | `[neonGreen, neonGreenHover]` | `[accentLime, accentLimeDim]` |
| `secondaryGradient` | `[navy700, navy800]` | `[surfaceV2Elevated, surfaceV2]` |
| `premiumGradient` | `[navy800, navy700]` | `[surfaceV2, surfaceV2Elevated]` |
| `motivationalGradient` | `[navy700, neonGreen]` | `[surfaceV2Elevated, accentLime]` |
| `achievementGradient` | `[navy800, neonGreen]` | `[surfaceV2, accentLime]` |
| `streakGradient` | `[navy700, navy800, neonGreenHover]` | `[surfaceV2Elevated, surfaceV2, accentLimeDim]` |
| `cardGradient` | `[navy800, navy700]` | `[surfaceV2, surfaceV2Elevated]` |

The `splashGradient` (4 navy shades for splash background) is replaced with true-black v2 surface shades: `[backgroundV2, surfaceV2, surfaceV2Elevated, surfaceV2Active]` with the same stop structure.

---

## 3. AppTheme.textTheme — Updated Slot Mapping

The `textTheme` in both `darkTheme` and `lightTheme` delegates to `AppTextStyles`:

| TextTheme slot | Maps to |
|----------------|---------|
| `displayLarge` | `AppTextStyles.display` |
| `displayMedium` | `AppTextStyles.h1` |
| `headlineLarge` | `AppTextStyles.h2` |
| `headlineMedium` | `AppTextStyles.h3` |
| `titleLarge` | `AppTextStyles.h3` |
| `titleMedium` | `AppTextStyles.bodyLarge` |
| `bodyLarge` | `AppTextStyles.bodyLarge` |
| `bodyMedium` | `AppTextStyles.body` |
| `labelLarge` | `AppTextStyles.label` |
| `labelSmall` | `AppTextStyles.caption` |

---

## 4. Component Specs — Key Screens

### Card (feed post, session card, streak card)

| Property | Value |
|----------|-------|
| Background | `AppColors.surfaceV2` (#111111) |
| Border | none (rely on surface elevation) |
| Corner radius | `AppBorderRadius.xl` (20pt) |
| Internal padding | `AppSpacing.lg` (16pt) all sides |
| Pressed state | `AppAnimations.cardPressScale` (0.98×) scale |

### Primary CTA Button ("Start Session", "Get Started")

| Property | Value |
|----------|-------|
| Background | `AppColors.accentLime` (#C8FF00) |
| Foreground | `AppColors.backgroundV2` (#080808) |
| Label style | `AppTextStyles.label` |
| Padding | `AppSpacing.xl` (24) horizontal, `AppSpacing.lg` (16) vertical |
| Corner radius | `AppBorderRadius.md` (12pt) |
| Pressed state | `AppAnimations.buttonPressScale` (0.96×) scale |

### Section separator / spacing

| Context | Spacing |
|---------|---------|
| Between major screen sections | `AppSpacing.xl` (24pt) |
| Between card list items | `AppSpacing.md` (12pt) |
| Intra-card between elements | `AppSpacing.sm` (8pt) |

---

## 5. Files to Migrate

### Typography migration (inline GoogleFonts → AppTextStyles)
37 widget files — see full list in research.md. Key files:
- `lib/features/auth/presentation/splash_page.dart`
- `lib/features/auth/presentation/onboarding_page.dart`
- `lib/features/feed/presentation/feed_page.dart`
- `lib/features/profile/presentation/profile_page.dart`
- `lib/features/session/presentation/session_room_page.dart` (also has w900 → w700 fix)
- `lib/widgets/streak_card.dart` (w900 → w700 fix)
- `lib/features/session/presentation/widgets/rep_counter_screen.dart` (w900 → w700 fix)

### Token migration (legacy → v2)
- `lib/widgets/reaction_buttons.dart`
- `lib/widgets/premium_effects.dart`
- `lib/core/theme/app_theme.dart` (alias + gradient updates)
