# Quickstart: Premium UI/UX Redesign — Integration Test Scenarios

**Branch**: `003-premium-ui-redesign`
**Date**: 2026-05-26

These are the manual acceptance scenarios to run after implementation is complete. Each scenario maps to one or more spec success criteria.

---

## Scenario 1 — Typography Renders Without Distortion (SC-001)

**Setup**: Build and run the app on a physical device or simulator (test on at least one small screen ≤375pt, one medium ~390pt, one large ≥430pt).

**Steps**:
1. Open the splash screen. Inspect the "zyntro" wordmark.
   - **Pass**: Letters are evenly spaced, not stretched horizontally, not blurry. Weight reads as bold-but-not-distorted.
   - **Fail**: Any glyph appears wider than tall, strokes look artificially widened, or text looks "painted on."

2. Navigate to the onboarding flow. Read the step headings and body copy.
   - **Pass**: Headings are visually distinct from body copy; body reads light and airy (Outfit w400–w500).
   - **Fail**: Body copy appears as heavy as headings; any text looks wider than it should be.

3. Navigate to the session setup screen. Read the screen title and input labels.
   - **Pass**: Title uses a Syne style (w600–w700); labels use Outfit (w400–w600). Both read crisply.
   - **Fail**: Any label appears distorted or mismatched in weight.

4. Navigate to the active session screen (rep counter).
   - **Pass**: The rep count number is large and bold, but the strokes are smooth — not artificially widened.
   - **Fail**: The rep counter number looks stretched or blurred (was previously Syne w900 → synthesised).

5. Navigate to the feed. Read post body copy and card metadata.
   - **Pass**: Body copy (Outfit w400) reads at a comfortable weight; metadata captions are clearly lighter.
   - **Fail**: Any text appears unexpectedly heavy or wide.

6. Navigate to the profile screen. Read stat labels and section headings.
   - **Pass**: Stats and labels are legible and well-proportioned.

---

## Scenario 2 — Type Scale Audit (SC-002)

**Setup**: Code search (can be automated).

```powershell
# Find any remaining inline GoogleFonts calls in widget files
rg "GoogleFonts\.(syne|outfit)\(" lib/ --type dart -l
```

**Pass**: Zero results (all calls have been migrated to `AppTextStyles`).
**Fail**: Any file under `lib/` still calls `GoogleFonts.syne()` or `GoogleFonts.outfit()` directly, except for `lib/core/theme/app_text_styles.dart` and `lib/core/theme/app_theme.dart` themselves.

---

## Scenario 3 — Zero Legacy Tokens on Screen (SC-003)

**Setup**: Code search.

```powershell
# Check for banned token references in widget files
rg "AppColors\.(navy900|navy800|navy700|neonGreen|neonGreenHover)" lib/ --type dart -l
# Exclude app_theme.dart (constant declarations) from the result
```

**Pass**: Only `lib/core/theme/app_theme.dart` appears (constant declarations only — no usages).
**Fail**: Any widget or page file references a banned token.

```powershell
# Also verify no raw hex values matching the banned palette
rg "0xFF0A0E27|0xFF151B3D|0xFF1E2749|0xFF39FF14|0xFF2EE00F" lib/ --type dart -l
```

**Pass**: Zero results outside `app_theme.dart`.

---

## Scenario 4 — Premium Feel at 1.3× Text Scale (SC-001, FR-011)

**Setup**: On iOS: Settings → Accessibility → Larger Text → drag slider to maximum. On Android: Settings → Font size → Largest. Run the app.

**Steps**:
1. Open the feed screen. Scroll through several cards.
   - **Pass**: Cards expand gracefully; text remains readable; no text overflow or truncation with "...".
2. Open the active session screen.
   - **Pass**: Rep counter and action button label remain readable and contained within their layout.
3. Open the profile screen.
   - **Pass**: Stat labels and section headings remain legible.

**Note**: The text scale cap at 1.3× means device font sizes above that do not further enlarge app text. Verify this is active by confirming text does NOT scale beyond the 1.3× cap even at maximum system font size.

---

## Scenario 5 — Interactive Elements Have Pressed States (SC-005)

**Setup**: Run on a device; tap each element listed below. Observe visual response.

| Element | Location | Expected pressed state |
|---------|----------|----------------------|
| "Start Session" button | Session setup | 0.96× scale, brief (150ms) |
| "Get Started" button | Splash / onboarding | 0.96× scale |
| Feed post card | Feed | 0.98× scale |
| Streak card | Profile / feed | 0.98× scale |
| Primary CTA on active session | Session room | 0.96× scale |

**Pass**: Every element listed above has a visible, instantaneous (≤100ms) scale-down on tap.
**Fail**: Any element shows no visual change on tap.

---

## Scenario 6 — Consistent Background Across Screens (SC-003, US3)

**Setup**: Run the app in dark mode. Navigate through all 5 key screens.

1. Feed → Session Setup → Active Session → Profile → Onboarding (log out to access).

**Pass**: Background colour is identical true-black (#080808) on every screen. No screen shows a navy-blue tint.
**Fail**: Any screen shows a visible shade difference — a blue-ish or navy-tinted background.

---

## Scenario 7 — WCAG AA Contrast Check (SC-006)

**Setup**: Use a contrast ratio tool (e.g., Colour Contrast Analyser, or browser DevTools on a screenshot). Check the following pairs:

| Text token | Background token | Minimum ratio | Expected |
|------------|-----------------|---------------|---------|
| `textV2Primary` (#FFFFFF) | `backgroundV2` (#080808) | 4.5:1 | ~21:1 ✓ |
| `textV2Secondary` (#888888) | `backgroundV2` (#080808) | 4.5:1 | ~4.7:1 ✓ (borderline — verify) |
| `textV2Secondary` (#888888) | `surfaceV2` (#111111) | 4.5:1 | ~4.5:1 (verify) |
| `backgroundV2` (#080808) | `accentLime` (#C8FF00) | 4.5:1 | ~16:1 ✓ |
| `textV2Tertiary` (#444444) | `backgroundV2` (#080808) | 4.5:1 | ~2.7:1 ✗ — must NOT be used for body/UI text |

**Pass**: All body and UI text uses `textV2Primary` or `textV2Secondary` on their respective backgrounds and meets 4.5:1. `textV2Tertiary` is used only for decorative or disabled text (exempt from AA body-text requirement).
