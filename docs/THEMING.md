# Theming & design tokens

All visual values in the app come from **central token classes** so they can be
changed in one place. Use these — never hard-code raw values in widgets.

| Token class | What it holds | Example |
|-------------|---------------|---------|
| `AppColors` | Colors (surfaces, text, semantic, accent) | `AppColors.surfaceV2`, `AppColors.textV2Primary` |
| `AppTextStyles` | Type scale | `AppTextStyles.h3`, `AppTextStyles.body` |
| `AppSpacing` | Spacing steps | `AppSpacing.lg` |
| `AppBorderRadius` | Corner radii | `AppBorderRadius.lg` |
| `AppDurations` / `AppCurves` | Motion | `AppDurations.fast` |

## The accent color is per-user and DYNAMIC

Every user picks a neon accent during profile setup. That color is stored on
their profile and applied app-wide at runtime.

**Always use the dynamic accent in UI:**

```dart
color: AppColors.userAccent       // the user's accent (defaults to neon green)
color: AppColors.userAccentDim    // slightly darker, for pressed/secondary
```

`AppColors.userAccent` / `userAccentDim` are **mutable** (`static Color`, not
`const`). The root widget (`ZyntroApp`) sets them from the user's profile via
`AppColors.setAccent(color)` and rebuilds, so the whole UI re-colors.

**Do NOT use `AppColors.accentLime` / `accentLimeDim` in widgets.** Those are
`const` seed values only — the default the accent falls back to. They were the
source of the old problem below.

### The `const` trap (why we did this)

A `const` value is locked at compile time and can never become a runtime value.
The accent used to be `const AppColors.accentLime`, referenced ~300 times, many
inside `const` widgets (`const Icon(... color: AppColors.accentLime)`). To make
the color per-user we had to convert it to a runtime value — but Dart forbids a
runtime value inside a `const` expression, so every one of those `const` widgets
had to be de-const'd. That's a large, error-prone migration.

**Rule to avoid repeating it:** anything that might need to change at runtime
(theme, accent, user preference, feature flags) must be a **non-const** token
(`static Color x = ...`) or come from a provider — never `const`. Keep `const`
only for values that are truly fixed forever (true black, pure white, fixed
semantic red, etc.).

### Adding a new themeable value

1. Add it to the right token class as a **non-const** `static` field if it can
   change at runtime, or `const` only if it's permanently fixed.
2. Reference it from widgets — never inline a literal.
3. If it should react to the user/profile, drive it from a Riverpod provider and
   apply it in `ZyntroApp.build` (see `accentColorProvider` + `AppColors.setAccent`).
