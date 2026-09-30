# Research: Premium UI/UX Redesign

**Branch**: `003-premium-ui-redesign`
**Date**: 2026-05-26
**Input**: spec.md + live codebase audit

---

## Decision 1: Root Cause of "Stretched/Heavy" Font Appearance

**Decision**: The primary cause is `FontWeight.w900` applied to Syne in 7 widget locations. Syne (via `google_fonts`) is a variable font with an axis range of 400–800. Requesting w900 forces Flutter's text engine to synthesise the extra weight by widening glyph strokes, producing the distorted/stretched appearance reported by the user.

**Evidence** (from codebase grep):
- `lib/widgets/streak_card.dart:156` — Syne w900
- `lib/features/session/presentation/session_room_page.dart` — Syne w900 ×4
- `lib/features/session/presentation/widgets/rep_counter_screen.dart` — Syne w900 ×2

**Secondary cause**: `FontWeight.w800` is used in 70 places. W800 is at the extreme of Syne's native range and reads visually heavy at smaller sizes (headings, labels). The same issue exists for Outfit, which supports 100–900 natively (no synthesis needed for w800/w900), but using w700+ for body text makes the app feel dense.

**Fix**: Cap Syne at w700; cap Outfit body text at w500. Use w600 for Outfit labels/buttons. This keeps text confident without triggering synthesis.

**Alternatives considered**: Swap typeface entirely (rejected — spec Assumption 2 retains Syne+Outfit); add `fontFamilyFallback` with a condensed variant (rejected — overcomplicated).

---

## Decision 2: AppTextStyles Architecture

**Decision**: Create `lib/core/theme/app_text_styles.dart` — a standalone `AppTextStyles` class with one named static getter per scale level. Each getter returns a `TextStyle` using `GoogleFonts`. The existing `AppTheme.darkTheme.textTheme` and `AppTheme.lightTheme.textTheme` slots are updated to delegate to `AppTextStyles` so that both the named-getter and `Theme.of(context).textTheme` paths produce consistent styles.

**Type scale definition**:

| Level | Font | Size (sp) | Weight | Letter-spacing | Line-height |
|-------|------|-----------|--------|----------------|-------------|
| display | Syne | 48 | w700 | −0.5 | 1.10 |
| h1 | Syne | 40 | w700 | −0.3 | 1.15 |
| h2 | Syne | 32 | w600 | 0 | 1.20 |
| h3 | Syne | 24 | w600 | 0 | 1.25 |
| bodyLarge | Outfit | 16 | w500 | 0 | 1.50 |
| body | Outfit | 14 | w400 | 0 | 1.50 |
| label | Outfit | 14 | w600 | 0.1 | 1.20 |
| caption | Outfit | 12 | w400 | 0.2 | 1.40 |

**Rationale**: Named getters (`AppTextStyles.display`) are more readable than `Theme.of(context).textTheme.displayLarge`. Keeping `textTheme` in sync ensures widgets that already use the Material theme slots get the fix automatically.

**Alternatives considered**: Pure `ThemeData.textTheme` migration (rejected — Material's fixed slot names don't map cleanly to the custom scale and require verbose `Theme.of(context)` boilerplate everywhere); inline fixes per-widget (rejected — does not address ad-hoc drift and fails SC-002).

---

## Decision 3: Text Scale Capping

**Decision**: Wrap `MaterialApp` with `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child)` inside `MaterialApp.builder`. This single change caps all text scaling at 1.3× app-wide without any per-widget logic.

**Rationale**: Flutter 3.10+ provides `TextScaler` and `MediaQuery.withClampedTextScaling` as the idiomatic way to bound text scaling. Applying it at the `MaterialApp.builder` level means every route and widget inherits the cap automatically.

**Alternatives considered**: Per-widget `MediaQuery.withClampedTextScaling` wrappers (rejected — too scattered, easy to miss); hardcoded `textScaleFactor: 1.0` override (rejected — completely disables accessibility, fails WCAG SC 1.4.4).

---

## Decision 4: Legacy Token Retirement Strategy

**Decision**: Update `AppColors` aliases and gradient presets in `app_theme.dart` so that `AppColors.primary`, `AppColors.action`, `AppColors.primaryGradient`, and warm/streak color aliases all point to v2 tokens (accentLime, surfaceV2Elevated). The legacy constant declarations (`navy900`, `neonGreen`, etc.) are kept as private/deprecated to preserve any indirect references, but no widget file may reference them directly. The 2 non-theme widget files (`reaction_buttons.dart`, `premium_effects.dart`) that reference legacy tokens are migrated to v2 tokens.

**Scope**: Only 3 files use legacy tokens outside `app_theme.dart` — far more contained than typical in a redesign of this scale.

**Alternatives considered**: Delete legacy constants immediately (rejected — could break tests referencing `AppColors.navy900` by name; safer to deprecate first).

---

## Decision 5: Key Screen Polish Strategy

**Decision**: Apply the following targeted improvements to the 5 key screens (in addition to the systemic token + typography fixes from Decisions 1–4):

- **Onboarding**: Standardise progress indicator style, header position, and button placement across all 5 steps.
- **Feed**: Ensure card padding is ≥16pt on all sides; fix any layout inconsistencies between post types.
- **Session Setup** (`gym_session_setup_page.dart`): Verify section spacing scale; confirm primary CTA prominence.
- **Active Session** (`session_room_page.dart`): Primary action button must be visually prominent; fix the 4× w900 instances here.
- **Profile** (`profile_page.dart`): Clear visual grouping for stats; accent used sparingly.

Secondary screens (settings, notifications, moderation, etc.) receive only token and typography fixes via the AppTextStyles migration — no bespoke layout work.

---

## Dependency on Existing Theme Infrastructure

`AppSpacing`, `AppBorderRadius`, and `AppFontSize` constants in `app_theme.dart` are well-defined and appropriate. No changes needed to spacing or radius constants. `AppTextStyles` references `AppFontSize` constants to stay consistent.

`AppDurations` and `AppCurves` are out of scope per spec Assumption 6 — no changes.
