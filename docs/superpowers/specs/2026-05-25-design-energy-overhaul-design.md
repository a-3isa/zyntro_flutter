# Zyntro Design & Energy Overhaul — Spec

**Date:** 2026-05-25  
**Skills applied:** `impeccable`, `emil-design-eng`, `taste`  
**Scope:** All presentation-layer files in `lib/features/` + `lib/widgets/` + `lib/core/theme/`

---

## 1. Goal

Transform Zyntro from a fitness tracker that looks like every other dark-mode app into a fitness **experience** that feels alive, energetic, and adrenaline-fuelled. Fix the 3 critical bugs blocking usability, correct the design system violations, and apply a full energy layer that makes users *feel* the workout.

---

## 2. Critical Bug Fixes (must ship first)

### 2.1 Social Tab Navigation
**File:** `lib/features/main/presentation/main_shell.dart`  
**Problem:** `SocialPage` is at `pages[2]` but no `_buildNavItem(index: 2)` exists. The social/community tab is completely unreachable.  
**Fix:** Add a community nav item (icon: `Icons.people_outline` / `Icons.people_rounded`) between the FAB and the profile item. The nav now has 4 destinations: Feed (0), Community (2), Profile (3), with the Session FAB centred.

### 2.2 Font Replacement
**Files:** `lib/core/theme/app_theme.dart`, all screens importing `GoogleFonts.dmSans` / `GoogleFonts.spaceGrotesk`  
**Problem:** Both current fonts (DM Sans, Space Grotesk) are on the `impeccable` banned list as generic 2025 AI defaults.  
**Fix:**
- **Display / headings:** `Syne` (weight 700–800) — angular, technical, high-energy
- **Body / UI labels:** `Outfit` (weight 400–600) — clean, modern, not overused
- Update `AppFonts.primary = 'Outfit'`, `AppFonts.display = 'Syne'`
- Add both to `pubspec.yaml` google_fonts list
- Replace all `GoogleFonts.spaceGrotesk(...)` → `GoogleFonts.syne(...)` and `GoogleFonts.dmSans(...)` → `GoogleFonts.outfit(...)`

### 2.3 Easing Curves
**File:** `lib/core/theme/app_theme.dart` (`AppCurves`)  
**Problem:** All curves use Flutter built-ins (`Curves.easeOutCubic` etc.) which feel weak per `emil-design-eng`.  
**Fix:** Replace with custom `Cubic` instances:
```dart
static const Curve premium    = Cubic(0.23, 1.00, 0.32, 1.00); // ease-out
static const Curve smooth     = Cubic(0.77, 0.00, 0.175, 1.00); // ease-in-out
static const Curve spring     = Cubic(0.34, 1.56, 0.64, 1.00); // overshoot spring
static const Curve decelerate = Cubic(0.00, 0.00, 0.20, 1.00); // fast-in slow-out
static const Curve press      = Cubic(0.23, 1.00, 0.32, 1.00); // button press (instant)
```

---

## 3. Design System Corrections

### 3.1 Brand-Tinted Shadows
**File:** `lib/core/theme/app_theme.dart` (`AppShadows`)  
Replace all pure-black shadow colours with lime-tinted equivalents:
```dart
// Before: Color(0x26000000)
// After:  Color(0x14C8FF00)  // accentLime @ 8%
sm  → BoxShadow(color: Color(0x0AC8FF00), blurRadius: 4,  offset: Offset(0, 2))
md  → BoxShadow(color: Color(0x12C8FF00), blurRadius: 12, offset: Offset(0, 4))
lg  → BoxShadow(color: Color(0x18C8FF00), blurRadius: 24, offset: Offset(0, 8))
xl  → BoxShadow(color: Color(0x20C8FF00), blurRadius: 32, offset: Offset(0, 12))
```

### 3.2 Implement Glow Tokens
**File:** `lib/core/theme/app_theme.dart`  
`primaryGlow`, `secondaryGlow`, `premiumGlow` are all `Colors.transparent`. Set to real values:
```dart
static const Color primaryGlow = Color(0x33C8FF00);  // lime @ 20%
static const Color premiumGlow = Color(0x1AC8FF00);  // lime @ 10%
static const Color secondaryGlow = Color(0x1A888888); // grey @ 10%
```
Update `AppShadows.primaryGlow`, `AppShadows.premiumGlow` to use these.

### 3.3 Button Press Animation Fix
**File:** `lib/widgets/zyntro_button.dart`  
Replace `Curves.easeInOut` in `_scaleController` with `AppCurves.press` (the new `Cubic(0.23, 1, 0.32, 1)`). Duration stays at `AppDurations.fast` (150ms). This makes the press feel instantaneous.

### 3.4 Spacing Scale (8px Grid)
**File:** `lib/core/theme/app_theme.dart` (`AppSpacing`)  
```dart
// Before: xs=4, sm=8, md=12, lg=16, xl=24, xxl=32, xxxl=48
// After:
static const double xs   = 4;
static const double sm   = 8;
static const double md   = 16;   // was 12 — now on 8px grid
static const double lg   = 24;   // was 16
static const double xl   = 32;   // was 24
static const double xxl  = 48;   // was 32
static const double xxxl = 64;   // was 48
```
Update all call sites — most usages of `AppSpacing.md` (12→16) and `AppSpacing.lg` (16→24) will need review.

### 3.5 Alert Dialogs → Design System
**File:** `lib/features/session/presentation/start_session_page.dart`  
Replace the raw `AlertDialog` + `ElevatedButton.styleFrom` with a `showModalBottomSheet` (or a styled `Dialog`) using v2 tokens (`surfaceV2Elevated`, `textV2Primary`) and `ZyntroButton` for all actions. Remove all v1 token references (`AppColors.primary`, `AppColors.error` → use `AppColors.accentLime`, `AppColors.errorV2`).

### 3.6 Input Focus Ring
**File:** `lib/features/auth/presentation/login_page.dart` (and all other auth pages)  
```dart
// Before: accentLime.withValues(alpha: 0.27) — invisible
// After:
focusedBorder: OutlineInputBorder(
  borderRadius: BorderRadius.circular(16),
  borderSide: BorderSide(color: AppColors.accentLime, width: 1.5),
),
// + outer container glow on focus using AppShadows with primaryGlow
```

---

## 4. Energy Layer — Making It Feel Alive

### 4.1 Session Timer — Dominant & Pulsing
**File:** `lib/features/session/presentation/session_room_page.dart` (and `session_page.dart`)  

The timer is the heartbeat of the session screen. Requirements:
- Font: `Syne`, 64px, weight 900, letterSpacing -3, colour `accentLime`
- Outer glow: `BoxShadow` using `primaryGlow` token, blurRadius 40
- Every second: `AnimationController` briefly scales the glow from 1.0→1.3→1.0 (400ms, `AppCurves.smooth`)
- Colour progression: `accentLime` (0–45min) → `warning` / `#FF8C00` (45–90min) → `errorV2` (90min+) — lerped via `ColorTween`
- Timer label: `Syne` 12px uppercase tracking-widest, `textV2Tertiary`, below the number

### 4.2 Rep Counter — Impact on Every Rep
**File:** `lib/features/session/presentation/widgets/active_turn_screen.dart`  

Each rep increment triggers:
1. Scale bounce: `1.0 → 1.18 → 1.0`, spring curve, 220ms
2. Brief colour flash: number goes `accentLime` for 80ms then back to white
3. `HapticFeedback.mediumImpact()` on increment
4. Set-complete event: scale `1.0 → 1.4 → 0.0 → 1.0`, `heavyImpact`, lime glow burst (opacity 1→0, 500ms)
5. Progress bar beneath: fills left-to-right as reps complete (`accentLime`, height 3px, `borderRadius 2`)

### 4.3 Workout Type Cards — Type-Specific Identity
**File:** `lib/features/session/presentation/start_session_page.dart`  

Each workout type card:
- Background: `AppColors.typeColor(type)` at 8% opacity on `surfaceV2`
- Left edge: 3px solid accent in full `typeColor`
- Diagonal shimmer accent: positioned `Positioned` element, rotated 35°, 40px wide, full card height, typeColor at 4% opacity
- Icon: typeColor at full opacity, 28px
- Type label chip: typeColor background at 12%, typeColor text, 11px weight 700
- Active/selected state: border increases to full typeColor at 100%, background to 15%, subtle glow shadow

### 4.4 "Friends Live Now" Strip
**File:** `lib/features/session/presentation/start_session_page.dart`  

Below the workout type grid, above the start button. Shows users who have an active session right now:
- Query: `SessionService.getActiveSessions()` filtered to current user's `following` list
- If 0 active friends: hidden
- If 1+: `Row` with stacked `CircleAvatar`s (28px, 2px lime border, -8px overlap), then text: `"{Name} +N are training now"`, then `LIVE` chip (red, pulsing dot)
- The pulsing dot: `AnimationController` 1400ms, scale 1.0→1.6→1.0, repeat
- Tapping the strip: navigates to social tab filtered to live sessions

### 4.5 Session Start Button — Launch Feel
**File:** `lib/features/session/presentation/start_session_page.dart`  

The primary CTA to start a session:
- Height: 64px (not the default 52px)
- Full width
- Label: `"Start {WorkoutType} Session"` (dynamic, not generic "Start")
- Sub-label: partner mode + plan name (e.g., "Solo · Upper body plan")
- On `onTapDown`: scale to 0.97 instantly (`AppCurves.press`, 80ms)
- On `onTapUp`: scale back to 1.0, then navigate with a 120ms delay for the animation to complete
- Background: `accentLime` flat fill (no gradient)
- On start: full-screen lime overlay ripple (opacity 0→0.15→0, 400ms) before navigation

### 4.6 Streak Visualization
**File:** `lib/widgets/streak_card.dart` and `lib/widgets/streak_widgets.dart`  

- Streak number: `Syne` 48px weight 900, `#FF8C00` (warm orange/amber)
- Fire emoji: 36px, positioned overlapping top-right of the number
- Count-up animation: on mount, number counts from 0 to current streak (800ms, `AppCurves.premium`)
- 7-day dot grid: Mon–Sun row, each 28×28px rounded-6 cells
  - Completed days: `#FF8C00` at 20% bg, `#FF8C00` text
  - Today (if completed): full `#FF8C00` bg, black text, bold
  - Future: `surfaceV2Elevated`, `textV2Tertiary`
- On mount: dots animate in staggered (each +40ms), scale 0→1, `AppCurves.spring`

### 4.7 Pulsing Live Indicators
**Files:** `lib/features/main/presentation/main_shell.dart`, `lib/features/session/presentation/session_room_page.dart`  

A reusable `PulseDot` widget:
```dart
// lib/widgets/pulse_dot.dart
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
}
// AnimationController: 1400ms, repeat
// Outer ring: scale 1.0→2.0, opacity 1.0→0.0
// Inner dot: static, full colour
```
Use on:
- Session FAB: when user has active session (lime pulse)
- User list items: when user is in active session
- Social tab indicator: when friends are live

### 4.8 Milestone Celebrations
**File:** new `lib/widgets/celebration_overlay.dart`  

A full-screen overlay triggered by:
- First workout completed
- 7-day streak reached  
- 10th, 25th, 50th session

Implementation:
- Use `confetti` package (already check pubspec — add if missing)
- `ConfettiController`, 3 seconds, colours `[accentLime, warning, white]`
- Achievement card slides up from bottom: dark surface, large emoji, title, subtitle
- Dismiss on tap or auto-dismiss after 4 seconds
- `HapticFeedback.heavyImpact()` on trigger

### 4.9 Feed Post — Workout Receipt Style
**Files:** `lib/features/feed/presentation/feed_page.dart`, `lib/features/feed/presentation/post_detail_page.dart`  

Workout posts restructured:
- **Header row:** type chip (typeColor bg at 12%, typeColor text) + username + timestamp
- **Stats row:** 3–4 key metrics in equal columns — exercises count, duration, PRs (if any), partner (if any). Each: large bold white number on top, small grey label below
- **Caption:** below stats, secondary, smaller — optional
- **Reactions:** unchanged
- Post background: no change to card surface, but type chip uses `AppColors.typeColor`
- Entry animation: each post slides in from Y+12 with opacity 0→1, 150ms, staggered 60ms per item, `AppCurves.premium`

---

## 5. Page Transitions

**File:** `lib/app/navigation/app_router.dart`  

Add custom `CustomTransitionPage` for all pushed routes:
```dart
// Slide from right (standard push)
transitionsBuilder: (ctx, anim, _, child) => SlideTransition(
  position: Tween(begin: Offset(1, 0), end: Offset.zero)
    .animate(CurvedAnimation(parent: anim, curve: AppCurves.premium)),
  child: child,
)
// Duration: 280ms
```

---

## 6. Nav Item Press Feedback

**File:** `lib/features/main/presentation/main_shell.dart`  

Wrap each `_buildNavItem` with a `GestureDetector` that handles `onTapDown` → scale 0.85 (spring, 100ms) and `onTapUp` → scale 1.0. The `AnimatedScale` on active state remains.

---

## 7. Files Touched (Summary)

| File | Changes |
|------|---------|
| `lib/core/theme/app_theme.dart` | Fonts, curves, shadows, glow tokens, spacing |
| `lib/features/main/presentation/main_shell.dart` | Social nav item, nav press feedback |
| `lib/features/session/presentation/session_room_page.dart` | Dominant timer, pulsing glow |
| `lib/features/session/presentation/widgets/active_turn_screen.dart` | Rep counter impact |
| `lib/features/session/presentation/start_session_page.dart` | Type cards, live strip, start button |
| `lib/widgets/streak_card.dart` + `streak_widgets.dart` | Fire streak visualization |
| `lib/widgets/zyntro_button.dart` | Press curve fix |
| `lib/widgets/pulse_dot.dart` | New reusable component |
| `lib/widgets/celebration_overlay.dart` | New milestone celebration |
| `lib/features/feed/presentation/feed_page.dart` | Workout receipt posts, stagger animation |
| `lib/app/navigation/app_router.dart` | Custom slide page transitions |
| All auth pages | Font replacement, focus ring fix |
| `pubspec.yaml` | Add Syne, Outfit fonts; confetti package |

---

## 8. Out of Scope

- Backend / Firestore data model changes
- New screens (no new routes added)
- Notification system changes
- Auth flow logic changes
- Any feature not listed above

---

## 9. Success Criteria

- Social tab is reachable from bottom nav
- No `GoogleFonts.dmSans` or `GoogleFonts.spaceGrotesk` calls remain
- All `AppCurves.*` use `Cubic(...)` not `Curves.*`
- Session timer pulses and changes colour over time
- Rep counter bounces on each increment
- Workout type cards have type-specific colour identity
- Friends live now strip appears when friends are active
- Streak card shows fire + count-up animation
- Feed posts lead with workout stats, not caption
- `flutter analyze` passes with no new warnings
