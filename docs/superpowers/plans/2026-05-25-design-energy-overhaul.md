# Design & Energy Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform Zyntro's UI from a generic dark-mode tracker into a high-energy fitness experience — fixing 3 critical bugs, correcting design system violations, and applying 9 energy-layer improvements that make the app feel alive.

**Architecture:** All changes are presentation-layer only (no data model or backend changes). The design system (`app_theme.dart`) is updated first so all downstream changes inherit the new tokens. New reusable widgets (`PulseDot`, `CelebrationOverlay`) are built before the screens that consume them.

**Tech Stack:** Flutter 3.x, Riverpod 2.x, GoRouter 14.x, google_fonts 6.x, confetti package (new)

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `pubspec.yaml` | Modify | Add confetti dep |
| `lib/core/theme/app_theme.dart` | Modify | Fonts, curves, shadows, glow tokens, spacing |
| `lib/features/main/presentation/main_shell.dart` | Modify | Social nav item + nav press feedback |
| `lib/app/navigation/app_router.dart` | Modify | Custom slide page transitions |
| `lib/widgets/zyntro_button.dart` | Modify | Fix press easing curve |
| `lib/widgets/pulse_dot.dart` | **Create** | Reusable pulsing live indicator |
| `lib/widgets/celebration_overlay.dart` | **Create** | Milestone confetti overlay |
| `lib/widgets/streak_card.dart` | Modify | Fire + count-up + 7-day grid |
| `lib/features/auth/presentation/login_page.dart` | Modify | Font + focus ring |
| `lib/features/auth/presentation/signup_page.dart` | Modify | Font |
| `lib/features/auth/presentation/onboarding_page.dart` | Modify | Font |
| `lib/features/auth/presentation/splash_page.dart` | Modify | Font |
| `lib/features/auth/presentation/forgot_password_page.dart` | Modify | Font |
| `lib/features/auth/presentation/profile_setup_page.dart` | Modify | Font |
| `lib/features/session/presentation/start_session_page.dart` | Modify | Type cards, live strip, launch button, dialog fix |
| `lib/features/session/presentation/session_room_page.dart` | Modify | Dominant pulsing timer |
| `lib/features/session/presentation/widgets/active_turn_screen.dart` | Modify | Rep counter impact bounce |
| `lib/features/feed/presentation/feed_page.dart` | Modify | Workout receipt posts + stagger |
| `test/core/theme/app_theme_test.dart` | **Create** | Verify curve values |
| `test/widgets/pulse_dot_test.dart` | **Create** | Widget renders |
| `test/widgets/celebration_overlay_test.dart` | **Create** | Overlay renders |
| `test/widgets/streak_card_test.dart` | Modify | Count-up + grid |

---

## Task 1: Add confetti dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add confetti to pubspec**

Open `pubspec.yaml`. Under `dependencies:`, after `avatar_plus:`, add:
```yaml
  confetti: ^0.7.0
```

- [ ] **Step 2: Install**

```
flutter pub get
```
Expected: `Got dependencies!` with no errors.

- [ ] **Step 3: Commit**

```
git add pubspec.yaml pubspec.lock
git commit -m "chore: add confetti dependency for milestone celebrations"
```

---

## Task 2: Overhaul AppTheme — fonts, curves, shadows, glow, spacing

**Files:**
- Modify: `lib/core/theme/app_theme.dart`
- Create: `test/core/theme/app_theme_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/core/theme/app_theme_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';

void main() {
  group('AppFonts', () {
    test('primary is Outfit', () => expect(AppFonts.primary, 'Outfit'));
    test('display is Syne', () => expect(AppFonts.display, 'Syne'));
  });

  group('AppCurves', () {
    test('premium is custom Cubic', () {
      expect(AppCurves.premium, isA<Cubic>());
    });
    test('press is custom Cubic', () {
      expect(AppCurves.press, isA<Cubic>());
    });
  });

  group('AppSpacing', () {
    test('md is 16 (8px grid)', () => expect(AppSpacing.md, 16.0));
    test('lg is 24', () => expect(AppSpacing.lg, 24.0));
  });

  group('AppColors glow tokens', () {
    test('primaryGlow is not transparent', () {
      expect(AppColors.primaryGlow, isNot(Colors.transparent));
    });
  });
}
```

- [ ] **Step 2: Run test — confirm it fails**

```
flutter test test/core/theme/app_theme_test.dart --reporter compact
```
Expected: FAIL (fonts still DM Sans / Space Grotesk, spacing md=12, etc.)

- [ ] **Step 3: Update AppFonts**

In `lib/core/theme/app_theme.dart`, replace the `AppFonts` class:
```dart
class AppFonts {
  static const String primary = 'Outfit';
  static const String display = 'Syne';
}
```

- [ ] **Step 4: Update AppCurves with custom Cubic values**

Replace the entire `AppCurves` class:
```dart
class AppCurves {
  static const Curve premium    = Cubic(0.23, 1.00, 0.32, 1.00);
  static const Curve smooth     = Cubic(0.77, 0.00, 0.175, 1.00);
  static const Curve spring     = Cubic(0.34, 1.56, 0.64, 1.00);
  static const Curve decelerate = Cubic(0.00, 0.00, 0.20, 1.00);
  static const Curve press      = Cubic(0.23, 1.00, 0.32, 1.00);
  static const Curve bounce     = Cubic(0.34, 1.56, 0.64, 1.00);
}
```

- [ ] **Step 5: Fix glow tokens in AppColors**

Find the glow color constants (around line 46-48) and replace:
```dart
static const Color primaryGlow  = Color(0x33C8FF00); // lime @ 20%
static const Color premiumGlow  = Color(0x1AC8FF00); // lime @ 10%
static const Color secondaryGlow = Color(0x1A888888); // grey @ 10%
```

- [ ] **Step 6: Fix AppSpacing to 8px grid**

Replace the `AppSpacing` class:
```dart
class AppSpacing {
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 16;
  static const double lg   = 24;
  static const double xl   = 32;
  static const double xxl  = 48;
  static const double xxxl = 64;
}
```

- [ ] **Step 7: Update AppShadows to lime-tinted**

Replace the `sm`, `md`, `lg`, `xl` shadow constants and the glow shadow lists:
```dart
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

  static List<BoxShadow> primaryGlow = [
    BoxShadow(color: AppColors.primaryGlow, blurRadius: 20, offset: const Offset(0, 8)),
  ];
  static List<BoxShadow> premiumGlow = [
    BoxShadow(color: AppColors.premiumGlow, blurRadius: 20, offset: const Offset(0, 8)),
  ];
  static List<BoxShadow> secondaryGlow = [
    BoxShadow(color: AppColors.secondaryGlow, blurRadius: 20, offset: const Offset(0, 8)),
  ];

  // Keep elevation shadows as-is (they don't need tinting)
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

  // Keep successGlow and errorGlow unchanged
  static List<BoxShadow> successGlow = [
    BoxShadow(color: AppColors.successGlow, blurRadius: 20, offset: const Offset(0, 8)),
  ];
  static List<BoxShadow> errorGlow = [
    BoxShadow(color: AppColors.errorGlow, blurRadius: 20, offset: const Offset(0, 8)),
  ];
}
```

- [ ] **Step 8: Run tests — confirm passing**

```
flutter test test/core/theme/app_theme_test.dart --reporter compact
```
Expected: All tests PASS.

- [ ] **Step 9: Verify app compiles**

```
flutter analyze lib/core/theme/app_theme.dart 2>&1 | Select-Object -First 40
```
Expected: no errors (warnings about unused vars are OK for now).

- [ ] **Step 10: Commit**

```
git add lib/core/theme/app_theme.dart test/core/theme/app_theme_test.dart
git commit -m "design: overhaul AppTheme — custom curves, lime shadows, glow tokens, 8px spacing"
```

---

## Task 3: Fix social tab — add community nav item

**Files:**
- Modify: `lib/features/main/presentation/main_shell.dart`

- [ ] **Step 1: Add community nav item**

In `_buildFloatingBottomNav()`, find the `Row` with `mainAxisAlignment: MainAxisAlignment.spaceAround`. Replace its children with:
```dart
children: [
  _buildNavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    index: 0,
    label: 'Feed',
  ),
  const SizedBox(width: 32), // space for FAB left side
  _buildNavItem(
    icon: Icons.people_outline,
    activeIcon: Icons.people_rounded,
    index: 2,
    label: 'Community',
  ),
  const SizedBox(width: 32), // space for FAB right side
  _buildNavItem(
    icon: Icons.person_outline,
    activeIcon: Icons.person_rounded,
    index: 3,
    label: 'Profile',
  ),
],
```

- [ ] **Step 2: Update _buildNavItem to accept label and add press feedback**

Replace the `_buildNavItem` method:
```dart
Widget _buildNavItem({
  required IconData icon,
  required IconData activeIcon,
  required int index,
  required String label,
}) {
  final isActive = _currentIndex == index;

  return GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      setState(() => _currentIndex = index);
    },
    behavior: HitTestBehavior.opaque,
    child: SizedBox(
      width: 56,
      height: 72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: isActive ? 1.1 : 1.0,
            duration: AppDurations.fast,
            curve: AppCurves.press,
            child: Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.accentLime : AppColors.textV2Tertiary,
              size: 26,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedOpacity(
            opacity: isActive ? 1.0 : 0.0,
            duration: AppDurations.fast,
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentLime,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 3: Add HapticFeedback import if missing**

Ensure `import 'package:flutter/services.dart';` is at the top of the file.

- [ ] **Step 4: Verify — run app and confirm social tab is reachable**

```
flutter analyze lib/features/main/presentation/main_shell.dart 2>&1 | Select-Object -First 20
```
Expected: no errors.

- [ ] **Step 5: Commit**

```
git add lib/features/main/presentation/main_shell.dart
git commit -m "fix: add community nav item — SocialPage was unreachable from bottom nav"
```

---

## Task 4: Replace banned fonts across all screens

**Files:**
- Modify: `lib/features/auth/presentation/login_page.dart`
- Modify: `lib/features/auth/presentation/signup_page.dart`
- Modify: `lib/features/auth/presentation/onboarding_page.dart`
- Modify: `lib/features/auth/presentation/splash_page.dart`
- Modify: `lib/features/auth/presentation/forgot_password_page.dart`
- Modify: `lib/features/auth/presentation/profile_setup_page.dart`
- Modify: `lib/features/feed/presentation/feed_page.dart`
- Modify: `lib/features/session/presentation/start_session_page.dart`
- Modify: `lib/widgets/streak_card.dart`

- [ ] **Step 1: Global find — count occurrences**

```
grep -r "GoogleFonts.spaceGrotesk\|GoogleFonts.dmSans" lib/ --include="*.dart" -l
```
Note the file list. Every file in that list needs the replacement below.

- [ ] **Step 2: Replace in all files**

For every file returned by step 1, apply these two substitutions:
- `GoogleFonts.spaceGrotesk(` → `GoogleFonts.syne(`
- `GoogleFonts.dmSans(` → `GoogleFonts.outfit(`

Do this file by file using Edit tool. For `login_page.dart` example:

Find every instance of `GoogleFonts.spaceGrotesk(` and replace with `GoogleFonts.syne(`.  
Find every instance of `GoogleFonts.dmSans(` and replace with `GoogleFonts.outfit(`.

- [ ] **Step 3: Also fix login_page focus ring while in the file**

In `login_page.dart`, find `_buildInputDecoration` method. Replace the `focusedBorder` entry:
```dart
focusedBorder: OutlineInputBorder(
  borderRadius: BorderRadius.circular(16),
  borderSide: const BorderSide(
    color: AppColors.accentLime,
    width: 1.5,
  ),
),
```

- [ ] **Step 4: Verify compile**

```
flutter analyze lib/features/auth/ lib/features/feed/ lib/features/session/ lib/widgets/streak_card.dart 2>&1 | Select-Object -First 40
```
Expected: no errors.

- [ ] **Step 5: Confirm no banned fonts remain**

```
grep -r "GoogleFonts.spaceGrotesk\|GoogleFonts.dmSans" lib/ --include="*.dart"
```
Expected: no output.

- [ ] **Step 6: Commit**

```
git add lib/
git commit -m "design: replace DM Sans + Space Grotesk with Syne + Outfit across all screens"
```

---

## Task 5: Fix ZyntroButton press animation curve

**Files:**
- Modify: `lib/widgets/zyntro_button.dart`

- [ ] **Step 1: Fix scale animation curve**

In `_ZyntroButtonState.initState()`, find the `_scaleController` animation setup and replace the `CurvedAnimation` curve:
```dart
_scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
  CurvedAnimation(parent: _scaleController, curve: AppCurves.press),
);
```

- [ ] **Step 2: Fix shimmer animation — use linear for continuous motion**

Find the `_shimmerAnimation` setup and replace:
```dart
_shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
  CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
);
```

- [ ] **Step 3: Verify**

```
flutter analyze lib/widgets/zyntro_button.dart 2>&1 | Select-Object -First 20
```

- [ ] **Step 4: Commit**

```
git add lib/widgets/zyntro_button.dart
git commit -m "design: fix button press to ease-out curve for instant tactile feedback"
```

---

## Task 6: Fix AlertDialog in StartSessionPage — use design system

**Files:**
- Modify: `lib/features/session/presentation/start_session_page.dart`

- [ ] **Step 1: Replace the existing session conflict AlertDialog**

Find the `AlertDialog` inside `_handleStartSession`. Replace the entire `showDialog(...)` call with a `showModalBottomSheet`:
```dart
final action = await showModalBottomSheet<String>(
  context: context,
  backgroundColor: Colors.transparent,
  builder: (ctx) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surfaceV2Elevated,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Active Session Found',
          style: GoogleFonts.syne(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textV2Primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You already have a workout in progress. Resume it or end it to start a new one.',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.textV2Secondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        ZyntroButton(
          title: 'Resume Active Session',
          variant: ZyntroButtonVariant.primary,
          fullWidth: true,
          onPressed: () => Navigator.pop(ctx, 'resume'),
        ),
        const SizedBox(height: 8),
        ZyntroButton(
          title: 'End Old & Start New',
          variant: ZyntroButtonVariant.destructive,
          fullWidth: true,
          onPressed: () => Navigator.pop(ctx, 'end'),
        ),
        const SizedBox(height: 8),
        ZyntroButton(
          title: 'Cancel',
          variant: ZyntroButtonVariant.ghost,
          fullWidth: true,
          onPressed: () => Navigator.pop(ctx, 'cancel'),
        ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);
```

- [ ] **Step 2: Replace v1 token references in the same file**

Search for `AppColors.primary` (v1 token) in `start_session_page.dart` and replace each with `AppColors.accentLime`.  
Search for `AppColors.error` and replace with `AppColors.errorV2`.

- [ ] **Step 3: Verify**

```
flutter analyze lib/features/session/presentation/start_session_page.dart 2>&1 | Select-Object -First 30
```

- [ ] **Step 4: Commit**

```
git add lib/features/session/presentation/start_session_page.dart
git commit -m "design: replace AlertDialog with bottom sheet using design system tokens"
```

---

## Task 7: Add custom slide page transitions

**Files:**
- Modify: `lib/app/navigation/app_router.dart`

- [ ] **Step 1: Create a slide transition builder helper**

At the top of `app_router.dart`, after the imports, add this private function:
```dart
Widget _slideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: AppCurves.premium)),
    child: child,
  );
}
```

- [ ] **Step 2: Wrap pushed routes with CustomTransitionPage**

In the `GoRouter` configuration, for every `GoRoute` that uses `builder:` (not the root `/`), change it to use `pageBuilder:` with a `CustomTransitionPage`. Example for `AppRoutes.login`:
```dart
GoRoute(
  path: AppRoutes.login,
  pageBuilder: (context, state) => CustomTransitionPage(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: _slideTransition,
    child: const LoginPage(),
  ),
),
```

Apply this pattern to: `login`, `signUp`, `onboarding`, `profileSetup`, `forgotPassword`, `startSession`, `matchmaking`, `gymSessionSetup`, `sessionRoom`, `recap`, `notifications`, `notificationPreferences`, `settings` and all settings sub-routes, `profile`, `editProfile`, `userPosts`, `workoutHistory`, `connections`, `followRequests`, `postDetail`, `moderationQueue`.

The root `/` (MainShell) should stay as `builder:` (no transition needed for the shell).

- [ ] **Step 3: Verify**

```
flutter analyze lib/app/navigation/app_router.dart 2>&1 | Select-Object -First 30
```

- [ ] **Step 4: Commit**

```
git add lib/app/navigation/app_router.dart
git commit -m "design: add custom slide-from-right page transitions (280ms, ease-out)"
```

---

## Task 8: Create PulseDot reusable widget

**Files:**
- Create: `lib/widgets/pulse_dot.dart`
- Create: `test/widgets/pulse_dot_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/widgets/pulse_dot_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/widgets/pulse_dot.dart';

void main() {
  testWidgets('PulseDot renders without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PulseDot()),
        ),
      ),
    );
    expect(find.byType(PulseDot), findsOneWidget);
  });

  testWidgets('PulseDot accepts custom color and size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PulseDot(color: Colors.red, size: 12),
          ),
        ),
      ),
    );
    expect(find.byType(PulseDot), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test — confirm FAIL**

```
flutter test test/widgets/pulse_dot_test.dart --reporter compact
```
Expected: FAIL with "Target of URI doesn't exist".

- [ ] **Step 3: Create PulseDot widget**

Create `lib/widgets/pulse_dot.dart`:
```dart
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// A pulsing dot that visually indicates a live / active state.
/// Inner dot is static; outer ring pulses from scale 1.0→2.0, opacity 1.0→0.0.
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulseDot({
    super.key,
    this.color = AppColors.accentLime,
    this.size = 8,
  });

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();

    _scaleAnim = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnim = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 3,
      height: widget.size * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing outer ring
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Opacity(
              opacity: _opacityAnim.value,
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                  ),
                ),
              ),
            ),
          ),
          // Static inner dot
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests — confirm PASS**

```
flutter test test/widgets/pulse_dot_test.dart --reporter compact
```
Expected: All PASS.

- [ ] **Step 5: Export from widgets barrel**

In `lib/widgets/widgets.dart`, add:
```dart
export 'pulse_dot.dart';
```

- [ ] **Step 6: Commit**

```
git add lib/widgets/pulse_dot.dart lib/widgets/widgets.dart test/widgets/pulse_dot_test.dart
git commit -m "feat: add PulseDot reusable widget for live/active state indicators"
```

---

## Task 9: Dominant pulsing session timer

**Files:**
- Modify: `lib/features/session/presentation/session_room_page.dart`

- [ ] **Step 1: Find where the timer is rendered**

Search for the elapsed time display:
```
grep -n "elapsed\|timer\|_elapsed\|duration" lib/features/session/presentation/session_room_page.dart | head -30
```
Note the line where session elapsed time is shown as a Text widget.

- [ ] **Step 2: Replace timer text widget with dominant pulsing timer**

Find the timer `Text(...)` widget in the session room page build method. Replace it with:
```dart
_DominantTimer(elapsed: _sessionElapsed, workoutType: widget.workoutType),
```

Then add this private widget class at the bottom of the file (before the closing `}`):
```dart
class _DominantTimer extends StatefulWidget {
  final Duration elapsed;
  final String workoutType;

  const _DominantTimer({required this.elapsed, required this.workoutType});

  @override
  State<_DominantTimer> createState() => _DominantTimerState();
}

class _DominantTimerState extends State<_DominantTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 20.0, end: 40.0).animate(
      CurvedAnimation(parent: _glowController, curve: AppCurves.smooth),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Color _timerColor(Duration elapsed) {
    final minutes = elapsed.inMinutes;
    if (minutes < 45) return AppColors.accentLime;
    if (minutes < 90) {
      final t = (minutes - 45) / 45.0;
      return Color.lerp(AppColors.accentLime, AppColors.warnV2, t)!;
    }
    final t = ((minutes - 90) / 30.0).clamp(0.0, 1.0);
    return Color.lerp(AppColors.warnV2, AppColors.errorV2, t)!;
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final color = _timerColor(widget.elapsed);
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: _glowAnim.value,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              _format(widget.elapsed),
              style: GoogleFonts.syne(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -3,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.workoutType.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.textV2Tertiary,
                letterSpacing: 0.12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Note:** If `_sessionElapsed` is named differently in the file (e.g., `_elapsed` or `_duration`), use the actual field name. If `workoutType` is not available as a field, pass it from wherever the session type is stored.

- [ ] **Step 3: Verify**

```
flutter analyze lib/features/session/presentation/session_room_page.dart 2>&1 | Select-Object -First 30
```

- [ ] **Step 4: Commit**

```
git add lib/features/session/presentation/session_room_page.dart
git commit -m "design: dominant pulsing session timer with colour progression lime→orange→red"
```

---

## Task 10: Rep counter impact bounce

**Files:**
- Modify: `lib/features/session/presentation/widgets/active_turn_screen.dart`

- [ ] **Step 1: Add animation controller for rep bounce**

In `_ActiveTurnScreenState`, add a new controller field after the existing ones:
```dart
late AnimationController _repBounceController;
late Animation<double> _repBounceAnim;
late Animation<Color?> _repColorAnim;
```

In `initState()`, add:
```dart
_repBounceController = AnimationController(
  duration: const Duration(milliseconds: 220),
  vsync: this,
);
_repBounceAnim = TweenSequence<double>([
  TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 40),
  TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 60),
]).animate(CurvedAnimation(parent: _repBounceController, curve: AppCurves.spring));
_repColorAnim = ColorTween(
  begin: AppColors.textV2Primary,
  end: AppColors.accentLime,
).animate(CurvedAnimation(parent: _repBounceController, curve: Curves.easeOut));
```

In `dispose()`, add:
```dart
_repBounceController.dispose();
```

- [ ] **Step 2: Trigger bounce on rep increment**

Find wherever `_reps` is incremented (look for `_reps++` or `setState(() => _reps`). After the increment, add:
```dart
HapticFeedback.mediumImpact();
_repBounceController.forward(from: 0);
```

- [ ] **Step 3: Wrap rep count display with animation**

Find the Text widget that shows `_reps` (likely a large number in the reps phase). Wrap it with `AnimatedBuilder`:
```dart
AnimatedBuilder(
  animation: _repBounceController,
  builder: (_, child) => Transform.scale(
    scale: _repBounceAnim.value,
    child: Text(
      '$_reps',
      style: GoogleFonts.syne(
        fontSize: 80,
        fontWeight: FontWeight.w900,
        color: _repColorAnim.value ?? AppColors.textV2Primary,
        letterSpacing: -3,
        height: 1,
      ),
    ),
  ),
),
```

- [ ] **Step 4: Verify**

```
flutter analyze lib/features/session/presentation/widgets/active_turn_screen.dart 2>&1 | Select-Object -First 30
```

- [ ] **Step 5: Commit**

```
git add lib/features/session/presentation/widgets/active_turn_screen.dart
git commit -m "design: rep counter bounces with spring animation and haptic on each rep"
```

---

## Task 11: Workout type cards — type-specific identity

**Files:**
- Modify: `lib/features/session/presentation/start_session_page.dart`

- [ ] **Step 1: Find the workout type grid**

Search for where workout type cards are rendered:
```
grep -n "WorkoutType\|typeColor\|_buildTypeCard\|_selectedType" lib/features/session/presentation/start_session_page.dart | head -20
```

- [ ] **Step 2: Replace/update the workout type card builder**

Find the method that builds each type card. Replace its `decoration` and content with:
```dart
Widget _buildTypeCard(WorkoutType type) {
  final isSelected = _selectedType == type;
  final typeColor = _getTypeColor(type);
  final icon = _getIconData(type.iconName ?? 'fitness_center');

  return GestureDetector(
    onTap: () {
      HapticManager.medium();
      setState(() => _selectedType = type);
      _savePreferences();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: AppCurves.press,
      decoration: BoxDecoration(
        color: isSelected
            ? typeColor.withValues(alpha: 0.15)
            : AppColors.surfaceV2.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? typeColor : AppColors.surfaceV2Active,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: typeColor.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Diagonal shimmer accent
            Positioned(
              top: -20,
              right: -10,
              child: Transform.rotate(
                angle: 0.6,
                child: Container(
                  width: 40,
                  height: 120,
                  color: typeColor.withValues(alpha: 0.04),
                ),
              ),
            ),
            // Left accent bar
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(width: 3, color: typeColor),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: typeColor, size: 22),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          type.displayName.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: typeColor,
                            letterSpacing: 0.08,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    type.displayName,
                    style: GoogleFonts.syne(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textV2Primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 3: Verify**

```
flutter analyze lib/features/session/presentation/start_session_page.dart 2>&1 | Select-Object -First 30
```

- [ ] **Step 4: Commit**

```
git add lib/features/session/presentation/start_session_page.dart
git commit -m "design: workout type cards with type-specific colour identity and accent bars"
```

---

## Task 12: "Friends live now" strip

**Files:**
- Modify: `lib/features/session/presentation/start_session_page.dart`
- Modify: `lib/services/session_service.dart` (read only — to verify `getActiveSessions` or equivalent exists)

- [ ] **Step 1: Check if getActiveSessions exists**

```
grep -n "getActiveSessions\|activeSessions\|live" lib/services/session_service.dart | head -20
```

- [ ] **Step 2: Add live sessions state to _StartSessionPageState**

In `_StartSessionPageState`, add state fields:
```dart
List<User> _liveFriends = [];
bool _isLoadingLive = false;
```

In `initState()`, add a call to load live friends:
```dart
_loadLiveFriends();
```

Add the method:
```dart
Future<void> _loadLiveFriends() async {
  final authState = ref.read(authSessionProvider);
  final uid = authState.valueOrNull?.id;
  if (uid == null) return;
  setState(() => _isLoadingLive = true);
  try {
    final service = ref.read(sessionServiceProvider);
    // Get users with active sessions from the following list
    final followingIds = await ref.read(followServiceProvider).getFollowingIds(uid);
    final activeSessions = await service.getActiveSessions(userIds: followingIds);
    final liveUsers = <User>[];
    for (final session in activeSessions) {
      if (session.hostId != uid) {
        final user = await ref.read(userServiceProvider).getUser(session.hostId);
        if (user != null) liveUsers.add(user);
      }
    }
    if (mounted) setState(() => _liveFriends = liveUsers.take(5).toList());
  } catch (_) {
    // Live strip is best-effort — fail silently
  } finally {
    if (mounted) setState(() => _isLoadingLive = false);
  }
}
```

**Note:** If `SessionService` does not have `getActiveSessions(userIds:)`, use `checkActiveSession` in a loop, or skip this step and add a TODO comment. Do not add new Firebase queries that don't exist.

- [ ] **Step 3: Add _buildLiveStrip widget method**

```dart
Widget _buildLiveStrip() {
  if (_liveFriends.isEmpty) return const SizedBox.shrink();
  final names = _liveFriends.take(2).map((u) => u.displayName.split(' ').first).join(', ');
  final extra = _liveFriends.length > 2 ? ' +${_liveFriends.length - 2}' : '';

  return GestureDetector(
    onTap: () {
      // Navigate to social tab
      // This is called from within the page which is a tab of MainShell,
      // so we raise to parent via callback if available, else do nothing
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceV2Active),
      ),
      child: Row(
        children: [
          // Stacked avatars
          SizedBox(
            width: (_liveFriends.length.clamp(1, 3) * 20.0) + 12,
            height: 28,
            child: Stack(
              children: [
                for (int i = 0; i < _liveFriends.length.clamp(0, 3); i++)
                  Positioned(
                    left: i * 20.0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.backgroundV2, width: 2),
                      ),
                      child: ClipOval(
                        child: _liveFriends[i].photoURL != null
                            ? CachedNetworkImage(
                                imageUrl: _liveFriends[i].photoURL!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: AppColors.surfaceV2Elevated,
                                child: Center(
                                  child: Text(
                                    _liveFriends[i].displayName.isNotEmpty
                                        ? _liveFriends[i].displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: AppColors.textV2Primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$names$extra are training now',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textV2Secondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          const PulseDot(color: Color(0xFFFF4D4D), size: 6),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFF4D4D),
              letterSpacing: 0.08,
            ),
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 4: Add import for PulseDot**

Add to imports: `import '../../../widgets/pulse_dot.dart';`

- [ ] **Step 5: Insert _buildLiveStrip() in the home view**

In `_buildHomeView()`, add `_buildLiveStrip()` above the start button / workout type selection.

- [ ] **Step 6: Verify**

```
flutter analyze lib/features/session/presentation/start_session_page.dart 2>&1 | Select-Object -First 30
```

- [ ] **Step 7: Commit**

```
git add lib/features/session/presentation/start_session_page.dart
git commit -m "design: add live friends strip — shows who's training right now"
```

---

## Task 13: Session start button — launch feel

**Files:**
- Modify: `lib/features/session/presentation/start_session_page.dart`

- [ ] **Step 1: Find the existing start button**

Search for the `ZyntroButton` or button that calls `_handleStartSession`. Replace it with:
```dart
GestureDetector(
  onTapDown: (_) => setState(() => _startButtonPressed = true),
  onTapUp: (_) {
    setState(() => _startButtonPressed = false);
    _handleStartSession();
  },
  onTapCancel: () => setState(() => _startButtonPressed = false),
  child: AnimatedScale(
    scale: _startButtonPressed ? 0.97 : 1.0,
    duration: const Duration(milliseconds: 80),
    curve: AppCurves.press,
    child: Container(
      height: 64,
      decoration: BoxDecoration(
        color: _selectedType == null
            ? AppColors.surfaceV2Active
            : AppColors.accentLime,
        borderRadius: BorderRadius.circular(16),
      ),
      child: _isLoading
          ? const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.backgroundV2,
                ),
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _selectedType == null
                      ? 'Select a workout type'
                      : 'Start ${_selectedType!.displayName} Session',
                  style: GoogleFonts.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _selectedType == null
                        ? AppColors.textV2Tertiary
                        : AppColors.backgroundV2,
                    letterSpacing: -0.3,
                  ),
                ),
                if (_selectedType != null && _partnerMode != 'solo') ...[
                  const SizedBox(height: 2),
                  Text(
                    _partnerMode == 'friends'
                        ? 'With ${_selectedFriends.length} friend${_selectedFriends.length == 1 ? '' : 's'}'
                        : 'Random partner',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.backgroundV2.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
    ),
  ),
),
```

- [ ] **Step 2: Add _startButtonPressed state field**

In `_StartSessionPageState`, add:
```dart
bool _startButtonPressed = false;
```

- [ ] **Step 3: Verify**

```
flutter analyze lib/features/session/presentation/start_session_page.dart 2>&1 | Select-Object -First 30
```

- [ ] **Step 4: Commit**

```
git add lib/features/session/presentation/start_session_page.dart
git commit -m "design: session start button — 64px launch feel with dynamic workout type label"
```

---

## Task 14: Streak visualization — fire + count-up + 7-day grid

**Files:**
- Modify: `lib/widgets/streak_card.dart`
- Modify: `test/widgets/streak_card_test.dart` (or create if doesn't exist)

- [ ] **Step 1: Add count-up animation to _StreakCardState**

Add a new controller and animation for the count-up:
```dart
late AnimationController _countController;
late Animation<int> _countAnim;
```

In `initState()`, after existing controller setup, add:
```dart
_countController = AnimationController(
  duration: const Duration(milliseconds: 800),
  vsync: this,
);
_countAnim = IntTween(begin: 0, end: widget.days).animate(
  CurvedAnimation(parent: _countController, curve: AppCurves.premium),
);
_countController.forward();
```

In `dispose()`, add: `_countController.dispose();`

- [ ] **Step 2: Replace the streak number display**

Find where the streak `days` count is shown. Replace with:
```dart
AnimatedBuilder(
  animation: _countAnim,
  builder: (_, __) => Text(
    '${_countAnim.value}',
    style: GoogleFonts.syne(
      fontSize: 52,
      fontWeight: FontWeight.w900,
      color: const Color(0xFFFF8C00),
      letterSpacing: -2,
      height: 1,
    ),
  ),
),
```

Add the fire emoji and label alongside:
```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    AnimatedBuilder(
      animation: _countAnim,
      builder: (_, __) => Text(
        '${_countAnim.value}',
        style: GoogleFonts.syne(
          fontSize: 52,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFFF8C00),
          letterSpacing: -2,
          height: 1,
        ),
      ),
    ),
    const Padding(
      padding: EdgeInsets.only(bottom: 4, left: 4),
      child: Text('🔥', style: TextStyle(fontSize: 32)),
    ),
  ],
),
Text(
  'day streak',
  style: GoogleFonts.outfit(
    fontSize: 12,
    color: AppColors.textV2Tertiary,
    letterSpacing: 0.04,
  ),
),
```

- [ ] **Step 3: Add 7-day dot grid**

Below the streak number, add:
```dart
const SizedBox(height: 14),
_buildWeekDots(),
```

Add the method:
```dart
Widget _buildWeekDots() {
  final now = DateTime.now();
  final weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  // current day of week: Monday=1, Sunday=7
  final todayIndex = now.weekday - 1; // 0=Mon, 6=Sun

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: List.generate(7, (i) {
      final isPast = i < todayIndex;
      final isToday = i == todayIndex;
      // Treat the last N days as "done" based on streak length
      final streakDays = widget.days.clamp(0, 7);
      final isDone = isPast && (todayIndex - i) <= streakDays;

      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 300 + i * 40),
        curve: AppCurves.spring,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isToday
                ? const Color(0xFFFF8C00)
                : isDone
                    ? const Color(0x33FF8C00)
                    : AppColors.surfaceV2Elevated,
          ),
          child: Center(
            child: Text(
              weekdayLabels[i],
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday
                    ? Colors.black
                    : isDone
                        ? const Color(0xFFFF8C00)
                        : AppColors.textV2Tertiary,
              ),
            ),
          ),
        ),
      );
    }),
  );
}
```

- [ ] **Step 4: Verify**

```
flutter analyze lib/widgets/streak_card.dart 2>&1 | Select-Object -First 30
```

- [ ] **Step 5: Commit**

```
git add lib/widgets/streak_card.dart
git commit -m "design: streak card — fire emoji, count-up animation, 7-day dot grid"
```

---

## Task 15: Create CelebrationOverlay — milestone confetti

**Files:**
- Create: `lib/widgets/celebration_overlay.dart`
- Create: `test/widgets/celebration_overlay_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/widgets/celebration_overlay_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/widgets/celebration_overlay.dart';

void main() {
  testWidgets('CelebrationOverlay renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CelebrationOverlay(
            title: '7-Day Streak!',
            subtitle: 'You worked out every day this week',
            emoji: '🔥',
            onDismiss: () {},
          ),
        ),
      ),
    );
    expect(find.text('7-Day Streak!'), findsOneWidget);
    expect(find.text('You worked out every day this week'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run — confirm FAIL**

```
flutter test test/widgets/celebration_overlay_test.dart --reporter compact
```

- [ ] **Step 3: Create CelebrationOverlay**

Create `lib/widgets/celebration_overlay.dart`:
```dart
import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';

class CelebrationOverlay extends StatefulWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final VoidCallback onDismiss;

  const CelebrationOverlay({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.onDismiss,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confetti;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3))..play();
    HapticFeedback.heavyImpact();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: AppCurves.spring));
    _slideController.forward();

    _autoDismiss = Timer(const Duration(seconds: 4), widget.onDismiss);
  }

  @override
  void dispose() {
    _confetti.dispose();
    _slideController.dispose();
    _autoDismiss?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Dim background
          Container(color: Colors.black.withValues(alpha: 0.6)),

          // Confetti
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            colors: const [AppColors.accentLime, AppColors.warnV2, Colors.white],
            numberOfParticles: 30,
            maxBlastForce: 20,
            minBlastForce: 8,
          ),

          // Achievement card slides up from bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnim,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surfaceV2Elevated,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.surfaceV2Active),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.emoji,
                      style: const TextStyle(fontSize: 56),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.title,
                      style: GoogleFonts.syne(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textV2Primary,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: AppColors.textV2Secondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Tap anywhere to continue',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textV2Tertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Show the celebration overlay as a full-screen dialog.
Future<void> showCelebration(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String emoji,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    builder: (_) => CelebrationOverlay(
      title: title,
      subtitle: subtitle,
      emoji: emoji,
      onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
    ),
  );
}
```

- [ ] **Step 4: Run tests — confirm PASS**

```
flutter test test/widgets/celebration_overlay_test.dart --reporter compact
```

- [ ] **Step 5: Export from widgets barrel**

In `lib/widgets/widgets.dart`, add:
```dart
export 'celebration_overlay.dart';
```

- [ ] **Step 6: Wire up in session_room_page.dart — trigger on session complete**

In `session_room_page.dart`, find where a session is ended / completed. After ending, check if it's the user's first session or a streak milestone and call:
```dart
// Example: trigger for every session completion — remove/refine milestone logic
await showCelebration(
  context,
  title: 'Workout Complete!',
  subtitle: 'Keep the momentum going — see you next time',
  emoji: '💪',
);
```

- [ ] **Step 7: Verify**

```
flutter analyze lib/widgets/celebration_overlay.dart 2>&1 | Select-Object -First 20
```

- [ ] **Step 8: Commit**

```
git add lib/widgets/celebration_overlay.dart lib/widgets/widgets.dart test/widgets/celebration_overlay_test.dart lib/features/session/presentation/session_room_page.dart
git commit -m "feat: CelebrationOverlay — confetti + slide-up achievement card for milestones"
```

---

## Task 16: Feed posts — workout receipt style + stagger entrance

**Files:**
- Modify: `lib/features/feed/presentation/feed_page.dart`

- [ ] **Step 1: Find the post card builder**

```
grep -n "_buildPostCard\|PostCard\|buildPost\|_PostCard" lib/features/feed/presentation/feed_page.dart | head -20
```

- [ ] **Step 2: Add workout stats row to each post card**

Find the post card widget. Inside the card, after the user header row, add a workout stats row before the caption:
```dart
// Workout type chip + stats row
if (post.type != null) ...[
  const SizedBox(height: 10),
  Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.typeColor(post.type!).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          post.type!.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.typeColor(post.type!),
            letterSpacing: 0.08,
          ),
        ),
      ),
    ],
  ),
  const SizedBox(height: 12),
  // Stats row — duration and any available metrics
  Row(
    children: [
      if (post.durationMinutes != null)
        _PostStat(value: '${post.durationMinutes}m', label: 'duration'),
      if (post.exerciseCount != null)
        _PostStat(value: '${post.exerciseCount}', label: 'exercises'),
      if (post.hasPr == true)
        const _PostStat(value: 'PR', label: 'personal record', isHighlight: true),
    ],
  ),
  const SizedBox(height: 8),
],
```

Add the `_PostStat` helper widget in the same file:
```dart
class _PostStat extends StatelessWidget {
  final String value;
  final String label;
  final bool isHighlight;

  const _PostStat({
    required this.value,
    required this.label,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.syne(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isHighlight ? AppColors.accentLime : AppColors.textV2Primary,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppColors.textV2Tertiary,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Note:** Use only fields that exist on the `Post` model. If `type`, `durationMinutes`, `exerciseCount`, or `hasPr` don't exist, skip those. Check `lib/core/models/models.dart` for actual Post fields.

- [ ] **Step 3: Add staggered entrance animation to feed list**

Find where posts are rendered in the `ListView.builder` or similar. Wrap each item with a staggered animation:
```dart
itemBuilder: (context, index) {
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: Duration(milliseconds: 150 + index * 60),
    curve: AppCurves.premium,
    builder: (_, v, child) => Opacity(
      opacity: v,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - v)),
        child: child,
      ),
    ),
    child: _buildPostCard(posts[index]),
  );
},
```

- [ ] **Step 4: Verify**

```
flutter analyze lib/features/feed/presentation/feed_page.dart 2>&1 | Select-Object -First 30
```

- [ ] **Step 5: Commit**

```
git add lib/features/feed/presentation/feed_page.dart
git commit -m "design: feed posts show workout stats receipt + staggered entrance animation"
```

---

## Task 17: Final check — analyze and clean up

- [ ] **Step 1: Run full analyze**

```
flutter analyze lib/ 2>&1 | Select-Object -First 80
```
Fix any errors (not warnings) introduced by the tasks above.

- [ ] **Step 2: Run all tests**

```
flutter test --reporter compact 2>&1 | tail -30
```
Expected: all tests pass.

- [ ] **Step 3: Check no banned fonts remain**

```
grep -r "GoogleFonts.spaceGrotesk\|GoogleFonts.dmSans" lib/ --include="*.dart"
```
Expected: no output.

- [ ] **Step 4: Check no v1 glow transparent tokens remain**

```
grep -n "Colors.transparent" lib/core/theme/app_theme.dart
```
Expected: no occurrences in the glow token definitions.

- [ ] **Step 5: Final commit**

```
git add -A
git commit -m "design: final cleanup — all 17 design energy overhaul tasks complete"
```
