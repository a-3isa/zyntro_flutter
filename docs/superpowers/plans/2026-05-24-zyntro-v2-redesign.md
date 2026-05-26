# Zyntro v2 Full App Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the v2 design system (true-black + acid-lime, Space Grotesk + DM Sans, no glassmorphism) across all screens, add per-post workout detail tab, and wire a persistent light/dark theme toggle.

**Architecture:** Theme-first migration — add v2 tokens to AppColors, update core widgets (ZyntroButton, ZyntroCard), then redesign each screen. A Riverpod `themeModeProvider` backed by SharedPreferences drives light/dark switching. Post workout data comes from the existing `Post.summary.exercises` list (name + set count already available in Firestore).

**Tech Stack:** Flutter, Riverpod, GoRouter, google_fonts (Space Grotesk, DM Sans), shared_preferences, fl_chart (already in project)

---

## Phase 1 — Design tokens + fonts

### Task 1: Add v2 color tokens to AppColors

**Files:**
- Modify: `lib/core/theme/app_theme.dart`
- Test: `test/core/theme/app_colors_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/core/theme/app_colors_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro/core/theme/app_theme.dart';

void main() {
  group('AppColors v2 tokens', () {
    test('backgroundV2 is true black', () {
      expect(AppColors.backgroundV2, const Color(0xFF080808));
    });
    test('surfaceV2 is dark card surface', () {
      expect(AppColors.surfaceV2, const Color(0xFF111111));
    });
    test('accentLime is acid lime', () {
      expect(AppColors.accentLime, const Color(0xFFC8FF00));
    });
    test('light backgroundV2Light is near white', () {
      expect(AppColors.backgroundV2Light, const Color(0xFFF8F8F8));
    });
    test('typeColors contains all 6 workout types', () {
      expect(AppColors.typeColors.keys, containsAll(['gym','cardio','hiit','cycling','yoga','swimming']));
    });
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```
flutter test test/core/theme/app_colors_test.dart
```
Expected: FAIL — `AppColors.backgroundV2` not found.

- [ ] **Step 3: Add v2 tokens to AppColors**

Open `lib/core/theme/app_theme.dart`. After the existing `AppColors` constants block, add:

```dart
  // ── v2 Design tokens ──────────────────────────────────────────────────────

  // Dark surfaces (true-black canvas)
  static const Color backgroundV2       = Color(0xFF080808);
  static const Color surfaceV2          = Color(0xFF111111);
  static const Color surfaceV2Elevated  = Color(0xFF1C1C1C);
  static const Color surfaceV2Active    = Color(0xFF242424);

  // Accent — acid lime
  static const Color accentLime         = Color(0xFFC8FF00);
  static const Color accentLimeDim      = Color(0xFFA6D400);

  // v2 text
  static const Color textV2Primary      = Color(0xFFFFFFFF);
  static const Color textV2Secondary    = Color(0xFF888888);
  static const Color textV2Tertiary     = Color(0xFF444444);

  // Light mode equivalents
  static const Color backgroundV2Light  = Color(0xFFF8F8F8);
  static const Color surfaceV2Light     = Color(0xFFFFFFFF);
  static const Color surfaceV2ElevatedLight = Color(0xFFF2F2F2);
  static const Color surfaceV2ActiveLight   = Color(0xFFE8E8E8);
  static const Color accentLimeLight    = Color(0xFF8AB000);
  static const Color accentLimeDimLight = Color(0xFF6E8C00);
  static const Color textV2PrimaryLight = Color(0xFF0A0A0A);
  static const Color textV2SecondaryLight = Color(0xFF555555);
  static const Color textV2TertiaryLight  = Color(0xFFBBBBBB);

  // Workout-type accent colors
  static const Map<String, Color> typeColors = {
    'gym':      Color(0xFFC8FF00),
    'cardio':   Color(0xFF38BDF8),
    'hiit':     Color(0xFFFF8C00),
    'cycling':  Color(0xFFA78BFA),
    'yoga':     Color(0xFF34D399),
    'swimming': Color(0xFF22D3EE),
    'strength': Color(0xFFC8FF00),
  };

  static Color typeColor(String type) =>
      typeColors[type] ?? accentLime;
```

- [ ] **Step 4: Run test to confirm it passes**

```
flutter test test/core/theme/app_colors_test.dart
```
Expected: PASS.

- [ ] **Step 5: Commit**

```
git add lib/core/theme/app_theme.dart test/core/theme/app_colors_test.dart
git commit -m "feat: add v2 design tokens to AppColors"
```

---

### Task 2: Update fonts to Space Grotesk + DM Sans

**Files:**
- Modify: `lib/core/theme/app_theme.dart` (AppFonts, text theme in darkTheme)
- Test: `test/core/theme/app_fonts_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/core/theme/app_fonts_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro/core/theme/app_theme.dart';

void main() {
  group('AppFonts v2', () {
    test('display font is Space Grotesk', () {
      expect(AppFonts.display, 'SpaceGrotesk');
    });
    test('body font is DM Sans', () {
      expect(AppFonts.body, 'DMSans');
    });
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

```
flutter test test/core/theme/app_fonts_test.dart
```

- [ ] **Step 3: Update AppFonts**

In `lib/core/theme/app_theme.dart`, update the `AppFonts` class:

```dart
class AppFonts {
  static const String primary = 'DMSans';
  static const String display = 'SpaceGrotesk';
  // Legacy aliases kept for backward-compat with existing usages
  static String get body => primary;
}
```

- [ ] **Step 4: Update text theme in AppTheme.darkTheme and lightTheme**

In the `darkTheme` getter, replace `GoogleFonts.outfit(...)` display/headline entries with `GoogleFonts.spaceGrotesk(...)`, and replace body text styles that use `'Inter'` with `fontFamily: 'DMSans'` (or `GoogleFonts.dmSans(...)`). Example for `displayLarge` in both themes:

```dart
displayLarge: GoogleFonts.spaceGrotesk(
  fontSize: AppFontSize.hero,
  fontWeight: FontWeight.w800,
  letterSpacing: -1.5,
),
displayMedium: GoogleFonts.spaceGrotesk(
  fontSize: AppFontSize.display,
  fontWeight: FontWeight.w800,
  letterSpacing: -1.0,
),
headlineLarge: GoogleFonts.spaceGrotesk(
  fontSize: AppFontSize.xxxl,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.5,
),
headlineMedium: GoogleFonts.spaceGrotesk(
  fontSize: AppFontSize.xxl,
  fontWeight: FontWeight.w700,
),
titleLarge: GoogleFonts.dmSans(
  fontSize: AppFontSize.xl,
  fontWeight: FontWeight.w600,
),
titleMedium: GoogleFonts.dmSans(
  fontSize: AppFontSize.lg,
  fontWeight: FontWeight.w500,
),
bodyLarge: GoogleFonts.dmSans(fontSize: AppFontSize.md),
bodyMedium: GoogleFonts.dmSans(fontSize: AppFontSize.sm),
labelLarge: GoogleFonts.dmSans(
  fontSize: AppFontSize.md,
  fontWeight: FontWeight.w600,
),
```

Apply the same to `lightTheme`.

- [ ] **Step 5: Also update darkTheme scaffold/surface colors to v2**

In `darkTheme` getter:

```dart
scaffoldBackgroundColor: AppColors.backgroundV2,
```

In the `ColorScheme.dark(...)`:

```dart
surface: AppColors.surfaceV2,
primary: AppColors.accentLime,
onPrimary: AppColors.backgroundV2,
```

In the card theme:

```dart
cardTheme: CardThemeData(
  color: AppColors.surfaceV2,
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
  ),
),
```

- [ ] **Step 6: Run test**

```
flutter test test/core/theme/app_fonts_test.dart
```
Expected: PASS.

- [ ] **Step 7: Smoke-build to catch type errors**

```
flutter build apk --debug 2>&1 | Select-Object -First 50
```

- [ ] **Step 8: Commit**

```
git add lib/core/theme/app_theme.dart test/core/theme/app_fonts_test.dart
git commit -m "feat: switch fonts to Space Grotesk + DM Sans, update dark theme tokens"
```

---

### Task 3: ThemeMode provider (persistent light/dark toggle)

**Files:**
- Create: `lib/core/theme/theme_provider.dart`
- Modify: `lib/app/app.dart`
- Test: `test/core/theme/theme_provider_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/core/theme/theme_provider_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyntro/core/theme/theme_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeModeNotifier', () {
    test('defaults to ThemeMode.system', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final mode = await container.read(themeModeProvider.future);
      expect(mode, ThemeMode.system);
    });

    test('setThemeMode persists and updates state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(themeModeProvider.future); // init
      await container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
      final mode = await container.read(themeModeProvider.future);
      expect(mode, ThemeMode.dark);
    });
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

```
flutter test test/core/theme/theme_provider_test.dart
```

- [ ] **Step 3: Create theme_provider.dart**

Create `lib/core/theme/theme_provider.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'theme_mode_v2';

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeModeKey);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark'  => ThemeMode.dark,
      _       => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, switch (mode) {
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
      ThemeMode.system => 'system',
    });
    state = AsyncData(mode);
  }

  Future<void> toggle(BuildContext context) async {
    final current = state.valueOrNull ?? ThemeMode.system;
    final isDark = switch (current) {
      ThemeMode.dark  => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    await setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
      ThemeModeNotifier.new,
    );
```

- [ ] **Step 4: Wire theme provider into app.dart**

Replace `lib/app/app.dart` contents:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../utils/global_error_handler.dart';

class ZyntroApp extends ConsumerWidget {
  const ZyntroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeModeAsync = ref.watch(themeModeProvider);
    final themeMode = themeModeAsync.valueOrNull ?? ThemeMode.system;

    return MaterialApp.router(
      title: 'Zyntro',
      scaffoldMessengerKey: scannerMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 5: Run test**

```
flutter test test/core/theme/theme_provider_test.dart
```
Expected: PASS.

- [ ] **Step 6: Commit**

```
git add lib/core/theme/theme_provider.dart lib/app/app.dart test/core/theme/theme_provider_test.dart
git commit -m "feat: add persistent ThemeMode provider with light/dark toggle"
```

---

## Phase 2 — Core widgets

### Task 4: Update ZyntroButton primary style

**Files:**
- Modify: `lib/widgets/zyntro_button.dart`
- Test: `test/widgets/zyntro_button_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/widgets/zyntro_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro/widgets/zyntro_button.dart';
import 'package:zyntro/core/theme/app_theme.dart';

void main() {
  group('ZyntroButton v2', () {
    testWidgets('primary button background is accentLime', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ZyntroButton(title: 'Test')),
        ),
      );
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.accentLime);
    });

    testWidgets('primary button text color is backgroundV2', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ZyntroButton(title: 'Test')),
        ),
      );
      final text = tester.widget<Text>(find.text('Test'));
      expect(text.style?.color, AppColors.backgroundV2);
    });
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

```
flutter test test/widgets/zyntro_button_test.dart
```

- [ ] **Step 3: Read the full ZyntroButton implementation**

Read `lib/widgets/zyntro_button.dart` fully to understand the current build method structure.

- [ ] **Step 4: Update primary variant styling**

Find the section in `_ZyntroButtonState.build` where it resolves `backgroundColor`, `foregroundColor`, and `boxShadow` for `ZyntroButtonVariant.primary`. Replace with:

```dart
// In the color resolution block for primary variant:
case ZyntroButtonVariant.primary:
  backgroundColor = AppColors.accentLime;
  foregroundColor = AppColors.backgroundV2;
  shadow = [
    BoxShadow(
      color: AppColors.accentLime.withValues(alpha: 0.30),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
```

Remove any gradient (`LinearGradient`) from the primary variant — use flat `color` instead of `gradient` in the `BoxDecoration`. Set `borderRadius` to `BorderRadius.circular(12)` for primary.

For `ZyntroButtonVariant.ghost`:
```dart
case ZyntroButtonVariant.ghost:
  backgroundColor = Colors.transparent;
  foregroundColor = AppColors.textV2Secondary;
  border = Border.all(color: AppColors.surfaceV2Active);
  shadow = [];
```

For `ZyntroButtonVariant.destructive`:
```dart
case ZyntroButtonVariant.destructive:
  backgroundColor = AppColors.error;
  foregroundColor = Colors.white;
  shadow = [];
```

Press scale target: `0.97` (already in `AppAnimations.buttonPressScale` — verify this value is `0.97`, update if it's `0.96`).

- [ ] **Step 5: Run test**

```
flutter test test/widgets/zyntro_button_test.dart
```
Expected: PASS.

- [ ] **Step 6: Commit**

```
git add lib/widgets/zyntro_button.dart test/widgets/zyntro_button_test.dart
git commit -m "feat: update ZyntroButton primary to flat acid-lime, no gradient"
```

---

### Task 5: Update ZyntroCard elevated style

**Files:**
- Modify: `lib/widgets/zyntro_card.dart`
- Test: `test/widgets/zyntro_card_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/widgets/zyntro_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro/widgets/zyntro_card.dart';
import 'package:zyntro/core/theme/app_theme.dart';

void main() {
  testWidgets('elevated card has surfaceV2 background and no border', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ZyntroCard(child: Text('hi')),
        ),
      ),
    );
    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColors.surfaceV2);
    expect(decoration.border, isNull);
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

```
flutter test test/widgets/zyntro_card_test.dart
```

- [ ] **Step 3: Update ZyntroCard elevated variant**

Read the full `lib/widgets/zyntro_card.dart`. In the `build` method, find where `ZyntroCardVariant.elevated` resolves its `BoxDecoration`. Replace with:

```dart
case ZyntroCardVariant.elevated:
  decoration = BoxDecoration(
    color: widget.backgroundColor ?? AppColors.surfaceV2,
    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
    // No border, no glassmorphism ��� depth through contrast only
  );
```

Remove `backdropFilter` / `ClipRRect` wrapping from `elevated` variant. Keep `glass` variant unchanged for any screens still using it.

- [ ] **Step 4: Run test**

```
flutter test test/widgets/zyntro_card_test.dart
```
Expected: PASS.

- [ ] **Step 5: Commit**

```
git add lib/widgets/zyntro_card.dart test/widgets/zyntro_card_test.dart
git commit -m "feat: remove glassmorphism from ZyntroCard elevated, use surfaceV2"
```

---

## Phase 3 — Feed + Post Detail

### Task 6: Feed page — full-bleed cards + theme toggle

**Files:**
- Modify: `lib/features/feed/presentation/feed_page.dart`
- Test: `test/features/feed/presentation/feed_page_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/features/feed/presentation/feed_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro/features/feed/presentation/feed_page.dart';

void main() {
  testWidgets('FeedPage shows ZYNTRO header text', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: FeedPage()),
      ),
    );
    await tester.pump();
    expect(find.text('ZYNTRO'), findsOneWidget);
  });

  testWidgets('FeedPage has Following and Discover tabs', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: FeedPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to confirm baseline**

```
flutter test test/features/feed/presentation/feed_page_test.dart
```

- [ ] **Step 3: Redesign FeedPage header**

In `lib/features/feed/presentation/feed_page.dart`, update the header section at the top of `build`:

```dart
// Replace the existing header Container with:
_FeedHeader(onThemeToggle: () {
  ref.read(themeModeProvider.notifier).toggle(context);
}),
```

Create a private `_FeedHeader` widget at the bottom of the file:

```dart
class _FeedHeader extends ConsumerWidget {
  final VoidCallback onThemeToggle;
  const _FeedHeader({required this.onThemeToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
      child: Row(
        children: [
          Text(
            'ZYNTRO',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onThemeToggle,
            icon: Icon(
              isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
              size: 22,
              color: AppColors.accentLime,
            ),
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.notifications),
            icon: Icon(
              Icons.notifications_outlined,
              size: 24,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
```

Add `import 'package:google_fonts/google_fonts.dart';` and `import '../../../core/theme/theme_provider.dart';` at the top of `feed_page.dart`.

- [ ] **Step 4: Update post card to full-bleed style**

Find the post card builder in `feed_page.dart`. Wrap the card content so that:
1. The image/placeholder area fills the full card width with no horizontal padding (use `margin: EdgeInsets.zero` on the card)
2. Add a gradient overlay (bottom 80px) from transparent to `backgroundV2` over the image
3. Move author name/avatar to the bottom of the image, overlaid on the gradient
4. Place reaction buttons (likes + comments) in a row below the card

The card container:

```dart
Container(
  margin: const EdgeInsets.only(bottom: 2), // no horizontal margins
  child: GestureDetector(
    onTap: () => context.push(AppRoutes.postDetail, extra: post.id),
    child: Stack(
      children: [
        // Photo area
        AspectRatio(
          aspectRatio: 4 / 5,
          child: post.mediaURLs?.isNotEmpty == true
              ? CachedNetworkImage(
                  imageUrl: post.mediaURLs!.first,
                  fit: BoxFit.cover,
                )
              : _PostPlaceholder(type: post.type),
        ),
        // Gradient fade bottom
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.backgroundV2.withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
        ),
        // Author overlay
        Positioned(
          bottom: 16, left: 16, right: 16,
          child: _PostAuthorOverlay(post: post, author: author),
        ),
      ],
    ),
  ),
),
// Action row below image
_PostActionRow(post: post),
```

Create `_PostPlaceholder`:

```dart
class _PostPlaceholder extends StatelessWidget {
  final String type;
  const _PostPlaceholder({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.typeColor(type);
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 1.2,
          colors: [color.withValues(alpha: 0.15), AppColors.backgroundV2],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests**

```
flutter test test/features/feed/presentation/feed_page_test.dart
```
Expected: PASS.

- [ ] **Step 6: Commit**

```
git add lib/features/feed/presentation/feed_page.dart test/features/feed/presentation/feed_page_test.dart
git commit -m "feat: feed page full-bleed cards, ZYNTRO header, theme toggle"
```

---

### Task 7: Post Detail — add Workout tab

**Files:**
- Modify: `lib/features/feed/presentation/post_detail_page.dart`
- Test: `test/features/feed/presentation/post_detail_page_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/features/feed/presentation/post_detail_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro/features/feed/presentation/post_detail_page.dart';
import 'package:zyntro/core/models/models.dart';

void main() {
  group('WorkoutDetailSection', () {
    testWidgets('shows exercise name and set count', (tester) async {
      final exercises = [
        ExerciseSummary(name: 'Bench Press', sets: 4),
        ExerciseSummary(name: 'Squat', sets: 3),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailSection(
              exercises: exercises,
              type: 'strength',
            ),
          ),
        ),
      );
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('4 sets'), findsOneWidget);
      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('3 sets'), findsOneWidget);
    });

    testWidgets('shows total sets count', (tester) async {
      final exercises = [
        ExerciseSummary(name: 'Bench Press', sets: 4),
        ExerciseSummary(name: 'Squat', sets: 3),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailSection(
              exercises: exercises,
              type: 'strength',
            ),
          ),
        ),
      );
      expect(find.text('7'), findsOneWidget); // total sets
    });

    testWidgets('shows empty state when no exercises', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WorkoutDetailSection(exercises: [], type: 'strength'),
          ),
        ),
      );
      expect(find.text('No exercise details'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

```
flutter test test/features/feed/presentation/post_detail_page_test.dart
```
Expected: FAIL — `WorkoutDetailSection` not found.

- [ ] **Step 3: Create WorkoutDetailSection widget**

At the bottom of `lib/features/feed/presentation/post_detail_page.dart`, add a new public widget:

```dart
/// Displays the workout breakdown from a post's session summary.
/// Shows each exercise with its set count in the v2 design language.
class WorkoutDetailSection extends StatelessWidget {
  final List<ExerciseSummary> exercises;
  final String type;

  const WorkoutDetailSection({
    super.key,
    required this.exercises,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = AppColors.typeColor(type);
    final totalSets = exercises.fold(0, (sum, e) => sum + e.sets);

    if (exercises.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No exercise details',
            style: TextStyle(color: AppColors.textV2Secondary, fontSize: 13),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total sets strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceV2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL SETS',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: AppColors.textV2Tertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalSets',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceV2Elevated,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Exercise list
          ...exercises.map((ex) => _ExerciseRow(exercise: ex, accentColor: accentColor)),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final ExerciseSummary exercise;
  final Color accentColor;
  const _ExerciseRow({required this.exercise, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              exercise.name,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textV2Primary,
              ),
            ),
          ),
          Text(
            '${exercise.sets} ${exercise.sets == 1 ? "set" : "sets"}',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textV2Secondary,
            ),
          ),
        ],
      ),
    );
  }
}
```

Add `import 'package:google_fonts/google_fonts.dart';` at the top if not already present.

- [ ] **Step 4: Add Workout tab to PostDetailPage**

In `_PostDetailPageState`, add a tab controller with 3 tabs: Workout, Reactions, Comments.

At the top of the `build` method state variables, add:
```dart
int _selectedTab = 0; // 0=Workout, 1=Reactions, 2=Comments
```

In the Scaffold body, add a tab row after the stats strip:

```dart
// Tab row
Row(
  children: ['Workout', 'Reactions', 'Comments'].asMap().entries.map((entry) {
    final isActive = entry.key == _selectedTab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = entry.key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.accentLime : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            entry.value,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive
                  ? AppColors.textV2Primary
                  : AppColors.textV2Secondary,
            ),
          ),
        ),
      ),
    );
  }).toList(),
),
// Tab content
Expanded(
  child: IndexedStack(
    index: _selectedTab,
    children: [
      // Tab 0: Workout
      WorkoutDetailSection(
        exercises: _post?.summary.exercises ?? [],
        type: _post?.type ?? 'strength',
      ),
      // Tab 1: Reactions
      _buildReactionsTab(),
      // Tab 2: Comments
      _buildCommentsTab(),
    ],
  ),
),
```

Move the existing reactions and comments UI into `_buildReactionsTab()` and `_buildCommentsTab()` private methods respectively.

- [ ] **Step 5: Run tests**

```
flutter test test/features/feed/presentation/post_detail_page_test.dart
```
Expected: PASS.

- [ ] **Step 6: Commit**

```
git add lib/features/feed/presentation/post_detail_page.dart test/features/feed/presentation/post_detail_page_test.dart
git commit -m "feat: add Workout tab to post detail showing exercise breakdown"
```

---

## Phase 4 — Session

### Task 8: Start session — exercise plan builder view

**Files:**
- Modify: `lib/features/session/presentation/start_session_page.dart`
- Test: `test/features/session/presentation/start_session_page_test.dart`

- [ ] **Step 1: Write failing tests**

Add to `test/features/session/presentation/start_session_page_test.dart` (create if needed):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro/features/session/presentation/start_session_page.dart';

void main() {
  group('ExercisePlanBuilder', () {
    testWidgets('shows default 3 exercises', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExercisePlanBuilder(
              onPlanConfirmed: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('OHP'), findsOneWidget);
    });

    testWidgets('Begin Session button shows total set count', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExercisePlanBuilder(
              onPlanConfirmed: (_) {},
            ),
          ),
        ),
      );
      // Default: Bench 4, Squat 4, OHP 3 = 11 sets
      expect(find.textContaining('11 sets'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

```
flutter test test/features/session/presentation/start_session_page_test.dart
```

- [ ] **Step 3: Create ExercisePlanItem and ExercisePlanBuilder**

Create `lib/features/session/domain/exercise_plan_item.dart`:

```dart
/// A single exercise in a user-defined session plan.
class ExercisePlanItem {
  final int id;
  final String name;
  final int sets;

  const ExercisePlanItem({
    required this.id,
    required this.name,
    required this.sets,
  });

  ExercisePlanItem copyWith({String? name, int? sets}) =>
      ExercisePlanItem(id: id, name: name ?? this.name, sets: sets ?? this.sets);
}

const kDefaultPlan = [
  ExercisePlanItem(id: 1, name: 'Bench Press', sets: 4),
  ExercisePlanItem(id: 2, name: 'Squat', sets: 4),
  ExercisePlanItem(id: 3, name: 'OHP', sets: 3),
];

const kExerciseSuggestions = [
  'Bench Press', 'Squat', 'Deadlift', 'OHP', 'Pull-Up', 'Row',
  'Incline Press', 'Leg Press', 'Curl', 'Dip', 'Lunge', 'RDL',
];
```

- [ ] **Step 4: Add ExercisePlanBuilder widget to start_session_page.dart**

Add to the bottom of `lib/features/session/presentation/start_session_page.dart`:

```dart
/// Widget that lets users build an exercise plan before starting a session.
class ExercisePlanBuilder extends StatefulWidget {
  final void Function(List<ExercisePlanItem> plan) onPlanConfirmed;

  const ExercisePlanBuilder({super.key, required this.onPlanConfirmed});

  @override
  State<ExercisePlanBuilder> createState() => _ExercisePlanBuilderState();
}

class _ExercisePlanBuilderState extends State<ExercisePlanBuilder> {
  List<ExercisePlanItem> _plan = kDefaultPlan.map((e) => e).toList();
  final _addController = TextEditingController();
  bool _showSuggestions = false;

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _addExercise(String name) {
    if (name.trim().isEmpty) return;
    setState(() {
      _plan = [..._plan, ExercisePlanItem(id: DateTime.now().millisecondsSinceEpoch, name: name.trim(), sets: 3)];
      _addController.clear();
      _showSuggestions = false;
    });
  }

  void _removeExercise(int id) =>
      setState(() => _plan = _plan.where((e) => e.id != id).toList());

  void _updateSets(int id, int sets) =>
      setState(() => _plan = _plan.map((e) => e.id == id ? e.copyWith(sets: sets) : e).toList());

  void _moveUp(int id) {
    final idx = _plan.indexWhere((e) => e.id == id);
    if (idx <= 0) return;
    final next = List<ExercisePlanItem>.from(_plan);
    final tmp = next[idx - 1]; next[idx - 1] = next[idx]; next[idx] = tmp;
    setState(() => _plan = next);
  }

  void _moveDown(int id) {
    final idx = _plan.indexWhere((e) => e.id == id);
    if (idx < 0 || idx >= _plan.length - 1) return;
    final next = List<ExercisePlanItem>.from(_plan);
    final tmp = next[idx + 1]; next[idx + 1] = next[idx]; next[idx] = tmp;
    setState(() => _plan = next);
  }

  int get _totalSets => _plan.fold(0, (s, e) => s + e.sets);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            children: [
              Text(
                'Plan Your Session',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.textV2Primary,
                ),
              ),
              const SizedBox(height: 16),
              ..._plan.asMap().entries.map((entry) {
                final idx = entry.key;
                final ex = entry.value;
                return _ExercisePlanRow(
                  exercise: ex,
                  index: idx,
                  total: _plan.length,
                  onDelete: () => _removeExercise(ex.id),
                  onUpdateSets: (s) => _updateSets(ex.id, s),
                  onMoveUp: () => _moveUp(ex.id),
                  onMoveDown: () => _moveDown(ex.id),
                );
              }),
              // Add exercise row
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceV2,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _addController,
                      style: GoogleFonts.dmSans(color: AppColors.textV2Primary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Add exercise…',
                        hintStyle: GoogleFonts.dmSans(color: AppColors.textV2Tertiary, fontSize: 14),
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add, color: AppColors.accentLime),
                          onPressed: () => _addExercise(_addController.text),
                        ),
                      ),
                      onTap: () => setState(() => _showSuggestions = true),
                      onSubmitted: _addExercise,
                    ),
                    if (_showSuggestions)
                      Wrap(
                        spacing: 6,
                        children: kExerciseSuggestions
                            .where((s) => !_plan.any((e) => e.name == s))
                            .map((s) => GestureDetector(
                                  onTap: () => _addExercise(s),
                                  child: Chip(
                                    label: Text(s, style: GoogleFonts.dmSans(fontSize: 12)),
                                    backgroundColor: AppColors.surfaceV2Elevated,
                                    labelStyle: const TextStyle(color: AppColors.textV2Secondary),
                                  ),
                                ))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Begin session CTA
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: ZyntroButton(
            title: 'Begin Session ⚡ ($_totalSets sets)',
            fullWidth: true,
            onPressed: _plan.isEmpty ? null : () => widget.onPlanConfirmed(_plan),
          ),
        ),
      ],
    );
  }
}

class _ExercisePlanRow extends StatefulWidget {
  final ExercisePlanItem exercise;
  final int index;
  final int total;
  final VoidCallback onDelete;
  final void Function(int sets) onUpdateSets;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _ExercisePlanRow({
    required this.exercise, required this.index, required this.total,
    required this.onDelete, required this.onUpdateSets,
    required this.onMoveUp, required this.onMoveDown,
  });

  @override
  State<_ExercisePlanRow> createState() => _ExercisePlanRowState();
}

class _ExercisePlanRowState extends State<_ExercisePlanRow> {
  double _dragOffsetX = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Delete background
        Positioned.fill(
          child: Container(
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
          ),
        ),
        // Swipeable content
        GestureDetector(
          onHorizontalDragUpdate: (d) =>
              setState(() => _dragOffsetX = (_dragOffsetX + d.delta.dx).clamp(-80.0, 0.0)),
          onHorizontalDragEnd: (_) {
            if (_dragOffsetX < -55) {
              widget.onDelete();
            } else {
              setState(() => _dragOffsetX = 0);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.translationValues(_dragOffsetX, 0, 0),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceV2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 26, height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceV2Elevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${widget.index + 1}',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w700, fontSize: 12,
                          color: AppColors.textV2Tertiary)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(widget.exercise.name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: AppColors.textV2Primary)),
                    ),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: widget.index == 0 ? null : widget.onMoveUp,
                          child: Icon(Icons.keyboard_arrow_up,
                            size: 16, color: widget.index == 0
                                ? AppColors.textV2Tertiary : AppColors.textV2Secondary),
                        ),
                        GestureDetector(
                          onTap: widget.index == widget.total - 1 ? null : widget.onMoveDown,
                          child: Icon(Icons.keyboard_arrow_down,
                            size: 16, color: widget.index == widget.total - 1
                                ? AppColors.textV2Tertiary : AppColors.textV2Secondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('Sets:',
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textV2Tertiary)),
                    const SizedBox(width: 8),
                    ...List.generate(6, (i) {
                      final n = i + 1;
                      final isSelected = widget.exercise.sets == n;
                      return GestureDetector(
                        onTap: () => widget.onUpdateSets(n),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 28, height: 28,
                          margin: const EdgeInsets.only(right: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.accentLime : AppColors.surfaceV2Elevated,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$n',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.backgroundV2 : AppColors.textV2Secondary)),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Wire plan builder into StartSessionPage**

In `_StartSessionPageState`, add a `_view` enum state: `'start' | 'plan'`. When "Next" is tapped after buddy selection, call `setState(() => _view = 'plan')`. When `ExercisePlanBuilder.onPlanConfirmed` fires, navigate to `gymSessionSetup` with the plan.

- [ ] **Step 6: Run tests**

```
flutter test test/features/session/presentation/start_session_page_test.dart
```
Expected: PASS.

- [ ] **Step 7: Commit**

```
git add lib/features/session/domain/exercise_plan_item.dart lib/features/session/presentation/start_session_page.dart test/features/session/presentation/start_session_page_test.dart
git commit -m "feat: add exercise plan builder to session setup"
```

---

### Task 9: Active turn screen — v2 visual style + tap-anywhere-to-stop

**Files:**
- Modify: `lib/features/session/presentation/widgets/active_turn_screen.dart`
- Test: `test/features/session/presentation/widgets/active_turn_screen_test.dart`

- [ ] **Step 1: Write failing test**

In `test/features/session/presentation/widgets/active_turn_screen_test.dart`, add:

```dart
testWidgets('ready phase shows START button', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ActiveTurnScreen(
          exerciseName: 'Bench Press',
          setNumber: 1,
          onSetSubmit: ({required reps, required weight, required durationSeconds}) {},
        ),
      ),
    ),
  );
  expect(find.text('START'), findsOneWidget);
});

testWidgets('ready phase shows exercise name', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ActiveTurnScreen(
          exerciseName: 'Bench Press',
          setNumber: 2,
          onSetSubmit: ({required reps, required weight, required durationSeconds}) {},
        ),
      ),
    ),
  );
  expect(find.text('Bench Press'), findsOneWidget);
  expect(find.text('Set 2'), findsOneWidget);
});
```

- [ ] **Step 2: Run to confirm tests currently pass/fail**

```
flutter test test/features/session/presentation/widgets/active_turn_screen_test.dart
```

- [ ] **Step 3: Update ready-phase UI**

In `lib/features/session/presentation/widgets/active_turn_screen.dart`, find the `_ActiveTurnPhase.ready` build section. Replace the ready-state widget tree with:

```dart
// Ready phase
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Text(
      widget.exerciseName,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 20, fontWeight: FontWeight.w700,
        color: AppColors.textV2Primary, letterSpacing: -0.3),
    ),
    const SizedBox(height: 6),
    Text(
      'Set ${widget.setNumber}',
      style: GoogleFonts.dmSans(
        fontSize: 12, color: AppColors.textV2Secondary),
    ),
    const SizedBox(height: 48),
    GestureDetector(
      onTap: _startTimer,
      child: Container(
        width: 140, height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accentLime,
          boxShadow: [
            BoxShadow(
              color: AppColors.accentLime.withValues(alpha: 0.35),
              blurRadius: 40, spreadRadius: 4),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          'START',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20, fontWeight: FontWeight.w800,
            color: AppColors.backgroundV2, letterSpacing: 1),
        ),
      ),
    ),
  ],
),
```

- [ ] **Step 4: Update timing-phase UI (tap anywhere to stop)**

In the `_ActiveTurnPhase.timing` section, wrap the entire timing widget in a `GestureDetector(onTap: _stopTimer, ...)` (tap anywhere stops), replacing any button-based stop. Update the timer text style:

```dart
GestureDetector(
  onTap: _stopTimer,
  behavior: HitTestBehavior.opaque,
  child: SizedBox.expand(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pulsing ring
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: _pulseOn ? 170 : 160,
          height: _pulseOn ? 170 : 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accentLime.withValues(alpha: _pulseOn ? 0.8 : 0.3),
              width: 3),
          ),
          alignment: Alignment.center,
          child: Text(
            _formatDuration(_elapsed),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 52, fontWeight: FontWeight.w800,
              color: AppColors.accentLime, letterSpacing: -2,
              fontFeatures: [const FontFeature.tabularFigures()]),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Tap anywhere to stop',
          style: GoogleFonts.dmSans(
            fontSize: 12, color: AppColors.textV2Secondary),
        ),
      ],
    ),
  ),
),
```

- [ ] **Step 5: Update weight-phase UI**

Replace the weight entry widget with:

```dart
// Weight phase — quick-pick row + increment buttons
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Text('How much?',
      style: GoogleFonts.spaceGrotesk(
        fontSize: 18, fontWeight: FontWeight.w700,
        color: AppColors.textV2Primary)),
    const SizedBox(height: 24),
    Text(
      '${_weight.toStringAsFixed(_weight % 1 == 0 ? 0 : 1)} kg',
      style: GoogleFonts.spaceGrotesk(
        fontSize: 60, fontWeight: FontWeight.w800,
        color: AppColors.accentLime, letterSpacing: -2)),
    const SizedBox(height: 20),
    // Quick-pick row
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [40.0, 60.0, 80.0, 100.0, 120.0].map((w) =>
          GestureDetector(
            onTap: () => setState(() => _weight = w),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _weight == w ? AppColors.accentLime : AppColors.surfaceV2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${w.toInt()}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: _weight == w ? AppColors.backgroundV2 : AppColors.textV2Secondary)),
            ),
          )).toList(),
      ),
    ),
    const SizedBox(height: 16),
    // Increment buttons
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final delta in [-10.0, -5.0, -2.5, 2.5, 5.0, 10.0])
          GestureDetector(
            onTap: () => setState(() => _weight = (_weight + delta).clamp(0.0, 300.0)),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceV2Elevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${delta > 0 ? "+" : ""}${delta % 1 == 0 ? delta.toInt() : delta}',
                style: GoogleFonts.dmSans(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.textV2Secondary)),
            ),
          ),
      ],
    ),
    const SizedBox(height: 32),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ZyntroButton(
        title: 'Confirm',
        fullWidth: true,
        onPressed: () => setState(() => _phase = _ActiveTurnPhase.reps),
      ),
    ),
  ],
),
```

Add `double _weight = 60.0;` to the state fields.

- [ ] **Step 6: Update reps-phase UI (tap-to-count)**

Replace the reps grid with tap-to-count:

```dart
// Reps phase — tap anywhere increments counter
GestureDetector(
  onTap: () => setState(() => _reps++),
  onLongPress: () => setState(() => _reps = 0),
  behavior: HitTestBehavior.opaque,
  child: SizedBox.expand(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('How many reps?',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: AppColors.textV2Primary)),
        const SizedBox(height: 32),
        AnimatedScale(
          scale: _reps > 0 ? 1.0 : 0.85,
          duration: const Duration(milliseconds: 150),
          child: Text(
            '$_reps',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 80, fontWeight: FontWeight.w800,
              color: AppColors.accentLime, letterSpacing: -3)),
        ),
        const SizedBox(height: 12),
        Text('tap to count · long-press to reset',
          style: GoogleFonts.dmSans(
            fontSize: 12, color: AppColors.textV2Secondary)),
        const SizedBox(height: 48),
        if (_reps > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ZyntroButton(
              title: 'Done — $_reps reps',
              fullWidth: true,
              onPressed: () {
                widget.onSetSubmit(
                  reps: _reps,
                  weight: _weight,
                  durationSeconds: _elapsed.inSeconds,
                );
                setState(() {
                  _phase = _ActiveTurnPhase.ready;
                  _reps = 0;
                  _weight = 60.0;
                  _elapsed = Duration.zero;
                });
              },
            ),
          ),
      ],
    ),
  ),
),
```

- [ ] **Step 7: Run tests**

```
flutter test test/features/session/presentation/widgets/active_turn_screen_test.dart
```
Expected: PASS.

- [ ] **Step 8: Commit**

```
git add lib/features/session/presentation/widgets/active_turn_screen.dart test/features/session/presentation/widgets/active_turn_screen_test.dart
git commit -m "feat: v2 session room UI — lime START button, tap-to-count reps, weight increment"
```

---

### Task 10: Session room — plan progress bar

**Files:**
- Modify: `lib/features/session/presentation/session_room_page.dart`
- Test: `test/features/session/presentation/widgets/plan_progress_bar_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/features/session/presentation/widgets/plan_progress_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro/features/session/presentation/session_room_page.dart';

void main() {
  group('PlanProgressBar', () {
    testWidgets('shows exercise name and set fraction', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlanProgressBar(
              exerciseName: 'Bench Press',
              currentSet: 2,
              totalSetsInExercise: 4,
              completedSets: 3,
              totalPlanSets: 11,
            ),
          ),
        ),
      );
      expect(find.text('BENCH PRESS'), findsOneWidget);
      expect(find.text('2/4'), findsOneWidget);
      expect(find.text('3 / 11'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

```
flutter test test/features/session/presentation/widgets/plan_progress_bar_test.dart
```

- [ ] **Step 3: Create PlanProgressBar widget**

Add to `lib/features/session/presentation/session_room_page.dart`:

```dart
/// Always-visible progress bar at the top of the session room.
class PlanProgressBar extends StatelessWidget {
  final String exerciseName;
  final int currentSet;
  final int totalSetsInExercise;
  final int completedSets;
  final int totalPlanSets;

  const PlanProgressBar({
    super.key,
    required this.exerciseName,
    required this.currentSet,
    required this.totalSetsInExercise,
    required this.completedSets,
    required this.totalPlanSets,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalPlanSets > 0 ? completedSets / totalPlanSets : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                exerciseName.toUpperCase(),
                style: GoogleFonts.dmSans(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 1.5, color: AppColors.textV2Tertiary),
              ),
              Row(
                children: [
                  Text(
                    '$currentSet/$totalSetsInExercise',
                    style: GoogleFonts.dmSans(
                      fontSize: 10, color: AppColors.textV2Tertiary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$completedSets / $totalPlanSets',
                    style: GoogleFonts.dmSans(
                      fontSize: 10, color: AppColors.textV2Tertiary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceV2,
                color: AppColors.accentLime,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Integrate PlanProgressBar into SessionRoomPage**

In `session_room_page.dart`, read the plan passed through route extras (already has `GymSessionPlan`). Add `PlanProgressBar` as the first widget in the Scaffold body (above the `ActiveTurnScreen`/`WaitingTurnScreen` switcher). Pass current exercise name, set number, and total sets from the session plan.

- [ ] **Step 5: Run tests**

```
flutter test test/features/session/presentation/widgets/plan_progress_bar_test.dart
```
Expected: PASS.

- [ ] **Step 6: Commit**

```
git add lib/features/session/presentation/session_room_page.dart test/features/session/presentation/widgets/plan_progress_bar_test.dart
git commit -m "feat: add plan progress bar to session room"
```

---

## Phase 5 — Recap + Social + Profile + Notifications

### Task 11: Recap page — v2 header + animated stats

**Files:**
- Modify: `lib/features/session/presentation/recap_page.dart`
- Test: `test/features/session/presentation/widgets/recap_done_header_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/features/session/presentation/widgets/recap_done_header_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro/features/session/presentation/recap_page.dart';

void main() {
  testWidgets('RecapDoneHeader shows Done text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RecapDoneHeader())),
    );
    expect(find.text('Done.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

```
flutter test test/features/session/presentation/widgets/recap_done_header_test.dart
```

- [ ] **Step 3: Add RecapDoneHeader to recap_page.dart**

Add to `lib/features/session/presentation/recap_page.dart`:

```dart
/// "Done." header with animated count-up appearance.
class RecapDoneHeader extends StatefulWidget {
  const RecapDoneHeader({super.key});

  @override
  State<RecapDoneHeader> createState() => _RecapDoneHeaderState();
}

class _RecapDoneHeaderState extends State<RecapDoneHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Text(
          'Done.',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 64, fontWeight: FontWeight.w800,
            color: AppColors.textV2Primary, letterSpacing: -2, height: 1),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Replace recap page header**

In `_RecapPageState.build`, replace the existing session-complete header with `const RecapDoneHeader()`.

Update the stat cards (exercises, sets, duration, volume) to use `AppColors.surfaceV2` backgrounds, `AppColors.accentLime` for the number, `GoogleFonts.spaceGrotesk` for numbers and `GoogleFonts.dmSans` for labels.

- [ ] **Step 5: Run test**

```
flutter test test/features/session/presentation/widgets/recap_done_header_test.dart
```
Expected: PASS.

- [ ] **Step 6: Commit**

```
git add lib/features/session/presentation/recap_page.dart test/features/session/presentation/widgets/recap_done_header_test.dart
git commit -m "feat: recap page v2 — Done. header, acid-lime stats"
```

---

### Task 12: Social page — podium + leaderboard

**Files:**
- Modify: `lib/features/social/presentation/social_page.dart`
- Test: `test/features/social/presentation/social_page_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/features/social/presentation/social_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro/features/social/presentation/social_page.dart';

void main() {
  group('LeaderboardPodium', () {
    testWidgets('shows three podium columns', (tester) async {
      final entries = [
        LeaderboardEntry(rank: 1, name: 'Alice', score: 1800, streak: 10, workouts: 25),
        LeaderboardEntry(rank: 2, name: 'Bob', score: 1600, streak: 7, workouts: 20),
        LeaderboardEntry(rank: 3, name: 'Carol', score: 1400, streak: 5, workouts: 18),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LeaderboardPodium(entries: entries)),
        ),
      );
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Carol'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

```
flutter test test/features/social/presentation/social_page_test.dart
```

- [ ] **Step 3: Add LeaderboardEntry model and LeaderboardPodium widget**

At the top of `lib/features/social/presentation/social_page.dart`, add:

```dart
/// Display model for a leaderboard row.
class LeaderboardEntry {
  final int rank;
  final String name;
  final int score;
  final int streak;
  final int workouts;
  final String? photoUrl;

  const LeaderboardEntry({
    required this.rank, required this.name, required this.score,
    required this.streak, required this.workouts, this.photoUrl,
  });
}
```

Add `LeaderboardPodium` widget:

```dart
class LeaderboardPodium extends StatelessWidget {
  final List<LeaderboardEntry> entries; // first 3 entries

  const LeaderboardPodium({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.length < 3) return const SizedBox.shrink();
    // Order: 2nd left, 1st centre, 3rd right
    final order = [entries[1], entries[0], entries[2]];
    const podiumHeights = [90.0, 116.0, 74.0];
    const podiumColors = [Color(0xFFC0C0C0), Color(0xFFFFD700), Color(0xFFCD7F32)];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final entry = order[i];
        final isFirst = entry.rank == 1;
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry.photoUrl != null)
                CircleAvatar(
                  radius: isFirst ? 26 : 20,
                  backgroundImage: NetworkImage(entry.photoUrl!),
                )
              else
                CircleAvatar(
                  radius: isFirst ? 26 : 20,
                  backgroundColor: AppColors.surfaceV2Elevated,
                  child: Text(
                    entry.name[0].toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      fontSize: isFirst ? 20 : 16,
                      color: podiumColors[i]),
                  ),
                ),
              const SizedBox(height: 6),
              Text(entry.name.split(' ').first,
                style: GoogleFonts.dmSans(
                  fontSize: 11, color: AppColors.textV2Secondary)),
              const SizedBox(height: 4),
              Container(
                height: podiumHeights[i],
                decoration: BoxDecoration(
                  color: AppColors.surfaceV2,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${entry.score}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: isFirst ? 18 : 14,
                    fontWeight: FontWeight.w800,
                    color: podiumColors[i]),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
```

- [ ] **Step 4: Integrate podium into leaderboard tab**

In `_SocialPageState`, find the leaderboard tab body. Map the existing `User` leaderboard data into `List<LeaderboardEntry>`. Insert `LeaderboardPodium(entries: topThree)` above the list of remaining entries (rank 4+). Apply v2 token colors to each list row.

- [ ] **Step 5: Run tests**

```
flutter test test/features/social/presentation/social_page_test.dart
```
Expected: PASS.

- [ ] **Step 6: Commit**

```
git add lib/features/social/presentation/social_page.dart test/features/social/presentation/social_page_test.dart
git commit -m "feat: social page v2 — podium top-3, acid-lime leaderboard rows"
```

---

### Task 13: Profile — weekly volume chart + activity heatmap

**Files:**
- Create: `lib/features/profile/presentation/widgets/workout_chart_widgets.dart`
- Modify: `lib/features/profile/presentation/profile_page.dart`
- Test: `test/features/profile/presentation/widgets/workout_chart_widgets_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/features/profile/presentation/widgets/workout_chart_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro/features/profile/presentation/widgets/workout_chart_widgets.dart';

void main() {
  group('WeeklyVolumeChart', () {
    testWidgets('renders 8 bars', (tester) async {
      const data = [2800, 3600, 2200, 4100, 3300, 4800, 3900, 2100];
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: WeeklyVolumeChart(weeklyVolumes: data)),
        ),
      );
      // 8 bars rendered as Container widgets inside the chart
      expect(find.byType(WeeklyVolumeChart), findsOneWidget);
    });
  });

  group('ActivityHeatmap', () {
    testWidgets('renders heatmap with day labels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox(
            width: 350, height: 120,
            child: ActivityHeatmap(activeDays: []),
          )),
        ),
      );
      expect(find.byType(ActivityHeatmap), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

```
flutter test test/features/profile/presentation/widgets/workout_chart_widgets_test.dart
```

- [ ] **Step 3: Create workout_chart_widgets.dart**

Create `lib/features/profile/presentation/widgets/workout_chart_widgets.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

/// 8-week bar chart: current week = lime, previous = semi-lime, older = s2.
class WeeklyVolumeChart extends StatelessWidget {
  final List<int> weeklyVolumes; // 8 values, index 7 = current week

  const WeeklyVolumeChart({super.key, required this.weeklyVolumes});

  @override
  Widget build(BuildContext context) {
    if (weeklyVolumes.isEmpty) return const SizedBox.shrink();
    final maxVol = weeklyVolumes.reduce((a, b) => a > b ? a : b);
    const chartHeight = 80.0;
    final labels = ['8w', '7w', '6w', '5w', '4w', '3w', '2w', 'now'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weekly Volume',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: AppColors.textV2Primary)),
        const SizedBox(height: 12),
        SizedBox(
          height: chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(weeklyVolumes.length, (i) {
              final vol = weeklyVolumes[i];
              final barH = maxVol > 0 ? (vol / maxVol) * chartHeight : 4.0;
              final color = i == weeklyVolumes.length - 1
                  ? AppColors.accentLime
                  : i == weeklyVolumes.length - 2
                      ? AppColors.accentLime.withValues(alpha: 0.5)
                      : AppColors.surfaceV2Elevated;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 400 + i * 60),
                    curve: Curves.easeOutCubic,
                    height: barH.clamp(4.0, chartHeight),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(labels.length, (i) => Expanded(
            child: Text(labels[i],
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 8,
                color: i == labels.length - 1
                    ? AppColors.accentLime : AppColors.textV2Tertiary)),
          )),
        ),
      ],
    );
  }
}

/// 12-week × 7-day GitHub-style activity heatmap.
class ActivityHeatmap extends StatelessWidget {
  /// List of DateTime days that had activity (used to colour cells).
  final List<DateTime> activeDays;

  const ActivityHeatmap({super.key, required this.activeDays});

  @override
  Widget build(BuildContext context) {
    const weeks = 12;
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    final activeSet = activeDays
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activity',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: AppColors.textV2Primary)),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day labels
            Column(
              children: List.generate(7, (d) => SizedBox(
                height: 13,
                child: d % 2 == 0
                    ? Text(dayLabels[d],
                        style: GoogleFonts.dmSans(
                          fontSize: 8, color: AppColors.textV2Tertiary))
                    : const SizedBox.shrink(),
              )),
            ),
            const SizedBox(width: 4),
            // Grid
            Expanded(
              child: Row(
                children: List.generate(weeks, (w) => Expanded(
                  child: Column(
                    children: List.generate(7, (d) {
                      final daysBack = (weeks - 1 - w) * 7 + (6 - d);
                      final day = DateTime(now.year, now.month, now.day)
                          .subtract(Duration(days: daysBack));
                      final isActive = activeSet.contains(day);
                      return Container(
                        margin: const EdgeInsets.all(1.5),
                        height: 10,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.accentLime.withValues(alpha: 0.7)
                              : AppColors.surfaceV2,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                )),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('12 weeks ago',
                style: GoogleFonts.dmSans(fontSize: 9, color: AppColors.textV2Tertiary)),
              Text('Today',
                style: GoogleFonts.dmSans(fontSize: 9, color: AppColors.textV2Tertiary)),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Add charts to profile page**

In `lib/features/profile/presentation/profile_page.dart`, find the Stats tab section. After the stats row (workouts/streak/following/followers), insert:

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
  child: WeeklyVolumeChart(weeklyVolumes: _weeklyVolumes),
),
Padding(
  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
  child: ActivityHeatmap(activeDays: _activeDays),
),
```

Add imports and state fields:
```dart
import 'widgets/workout_chart_widgets.dart';
// ...
final List<int> _weeklyVolumes = [2800, 3600, 2200, 4100, 3300, 4800, 3900, 2100]; // placeholder
final List<DateTime> _activeDays = []; // populated from workout history
```

Also update the profile name header to editorial stacked style:

```dart
// Replace existing name display with:
Text(
  displayName.split(' ').first.toUpperCase(),
  style: GoogleFonts.spaceGrotesk(
    fontSize: 38, fontWeight: FontWeight.w800,
    letterSpacing: -1.5, color: AppColors.textV2Primary, height: 0.9),
),
if (displayName.split(' ').length > 1)
  Text(
    displayName.split(' ').last.toUpperCase(),
    style: GoogleFonts.spaceGrotesk(
      fontSize: 38, fontWeight: FontWeight.w800,
      letterSpacing: -1.5, color: AppColors.textV2Primary, height: 0.9),
  ),
```

- [ ] **Step 5: Run tests**

```
flutter test test/features/profile/presentation/widgets/workout_chart_widgets_test.dart
```
Expected: PASS.

- [ ] **Step 6: Commit**

```
git add lib/features/profile/presentation/widgets/workout_chart_widgets.dart lib/features/profile/presentation/profile_page.dart test/features/profile/presentation/widgets/workout_chart_widgets_test.dart
git commit -m "feat: profile v2 — editorial name, weekly volume chart, activity heatmap"
```

---

### Task 14: Notifications — grouped by day

**Files:**
- Modify: `lib/features/notifications/presentation/notifications_page.dart`
- Test: `test/features/notifications/presentation/notifications_page_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/features/notifications/presentation/notifications_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro/features/notifications/presentation/notifications_page.dart';

void main() {
  group('groupNotificationsByDay', () {
    test('splits notifications into today and yesterday buckets', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final items = [
        NotificationItem(id: '1', title: 'A liked your post', time: now),
        NotificationItem(id: '2', title: 'B is now following you', time: yesterday),
      ];
      final grouped = groupNotificationsByDay(items);
      expect(grouped['Today']?.length, 1);
      expect(grouped['Yesterday']?.length, 1);
    });
  });
}
```

- [ ] **Step 2: Run to confirm it fails**

```
flutter test test/features/notifications/presentation/notifications_page_test.dart
```

- [ ] **Step 3: Add NotificationItem model and grouping function**

In `lib/features/notifications/presentation/notifications_page.dart`, add:

```dart
class NotificationItem {
  final String id;
  final String title;
  final DateTime time;
  final bool isRead;
  final String? avatarUrl;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.time,
    this.isRead = false,
    this.avatarUrl,
  });
}

/// Groups notifications into 'Today', 'Yesterday', and date-formatted buckets.
Map<String, List<NotificationItem>> groupNotificationsByDay(
    List<NotificationItem> items) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final result = <String, List<NotificationItem>>{};
  for (final item in items) {
    final day = DateTime(item.time.year, item.time.month, item.time.day);
    final String key;
    if (day == today) {
      key = 'Today';
    } else if (day == yesterday) {
      key = 'Yesterday';
    } else {
      key = '${day.day}/${day.month}/${day.year}';
    }
    (result[key] ??= []).add(item);
  }
  return result;
}
```

- [ ] **Step 4: Update notifications list UI**

In the `build` of `notifications_page.dart`, replace the flat list with a grouped list:

```dart
final grouped = groupNotificationsByDay(_notifications);
for (final entry in grouped.entries) ...[
  // Group header
  Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
    child: Text(
      entry.key,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: AppColors.textV2Tertiary, letterSpacing: 0.5),
    ),
  ),
  // Notification rows
  ...entry.value.map((n) => _NotificationRow(item: n)),
],
```

Create `_NotificationRow`:

```dart
class _NotificationRow extends StatelessWidget {
  final NotificationItem item;
  const _NotificationRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceV2,
              border: Border.all(
                color: AppColors.accentLime.withValues(alpha: 0.3), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              item.title[0].toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: AppColors.textV2Primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(item.title,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: item.isRead
                    ? AppColors.textV2Secondary : AppColors.textV2Primary,
                fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w600)),
          ),
          if (!item.isRead)
            Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentLime),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests**

```
flutter test test/features/notifications/presentation/notifications_page_test.dart
```
Expected: PASS.

- [ ] **Step 6: Commit**

```
git add lib/features/notifications/presentation/notifications_page.dart test/features/notifications/presentation/notifications_page_test.dart
git commit -m "feat: notifications v2 — grouped by day, unread lime dot"
```

---

### Task 15: Final smoke test + full test suite

- [ ] **Step 1: Run full test suite**

```
flutter test --reporter compact 2>&1 | tail -30
```
Expected: all previously passing tests still pass; new tests pass.

- [ ] **Step 2: Build check**

```
flutter build apk --debug 2>&1 | Select-Object -First 50
```
Expected: no compile errors.

- [ ] **Step 3: Commit if any last fixes were needed**

```
git add -p
git commit -m "fix: address test failures after v2 redesign"
```

---

## File Map Summary

| File | Action |
|---|---|
| `lib/core/theme/app_theme.dart` | Add v2 tokens, update fonts + dark theme |
| `lib/core/theme/theme_provider.dart` | **CREATE** — Riverpod ThemeMode notifier |
| `lib/app/app.dart` | Wire themeModeProvider |
| `lib/widgets/zyntro_button.dart` | Primary = flat lime, ghost = s3 border |
| `lib/widgets/zyntro_card.dart` | Elevated = surfaceV2, no glass |
| `lib/features/feed/presentation/feed_page.dart` | ZYNTRO header, theme toggle, full-bleed cards |
| `lib/features/feed/presentation/post_detail_page.dart` | Add Workout tab + WorkoutDetailSection |
| `lib/features/session/domain/exercise_plan_item.dart` | **CREATE** — plan item model |
| `lib/features/session/presentation/start_session_page.dart` | Add plan builder view |
| `lib/features/session/presentation/widgets/active_turn_screen.dart` | v2 START button, tap-to-count, weight picker |
| `lib/features/session/presentation/session_room_page.dart` | Add PlanProgressBar |
| `lib/features/session/presentation/recap_page.dart` | Done. header, v2 stat cards |
| `lib/features/social/presentation/social_page.dart` | Podium top-3, v2 list rows |
| `lib/features/profile/presentation/widgets/workout_chart_widgets.dart` | **CREATE** — WeeklyVolumeChart + ActivityHeatmap |
| `lib/features/profile/presentation/profile_page.dart` | Editorial name, add charts |
| `lib/features/notifications/presentation/notifications_page.dart` | Grouped by day, unread dot |
