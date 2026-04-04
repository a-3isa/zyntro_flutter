# App-Wide Theme Migration Design

Date: 2026-03-31

## Summary

Migrate the Flutter app from its current lime, purple, and glow-heavy visual system to the approved Figma navy and neon-green theme across the entire app. This is a visual-only migration: colors, surfaces, icon treatment, borders, and shared component styling will change, but app logic, feature behavior, routing, services, and state management will remain unchanged.

The migration will be driven primarily through shared theme tokens and shared UI primitives so most screens inherit the new look automatically. A smaller cleanup pass will update screens that still hard-code old accent colors or icon glow effects.

## Goals

- Apply the approved Figma theme across the whole app, not only the gym or session flow.
- Keep all logic, functions, flows, and data behavior unchanged.
- Replace the current black, lime, purple, and glossy-glow aesthetic with deep navy surfaces and neon-green accents.
- Remove icon glow treatments and pulsing glow halos across the app.
- Centralize the migration in shared theme tokens and shared widgets where possible.
- Preserve existing layouts and interaction structure while changing the visual language.

## Non-Goals

- Rewriting feature logic, navigation, service code, or state management.
- Rebuilding screens to match the Figma prototypes one-for-one.
- Performing a typography overhaul or changing app copy.
- Replacing all animations; only glow-style effects tied to icon treatment are in scope.
- Refactoring unrelated code outside the theme and visual surface work needed for this migration.

## Source Of Truth

- The Figma Make file is the source of truth for the approved color palette and icon mood.
- The existing Flutter codebase is the source of truth for app behavior and structure.
- The implementation target is the current app with a globally updated visual system.

## Approved Palette

Use these colors as the new visual foundation:

- `navy-900`: `#0A0E27`
- `navy-800`: `#151B3D`
- `navy-700`: `#1E2749`
- `neon-green`: `#39FF14`
- `neon-green-hover`: `#2EE00F`
- `gray-400`: `#8B8B98`
- `gray-300`: `#A0A0AC`

## Visual Direction

The app should feel:

- darker, cleaner, and more athletic
- high-contrast without feeling glossy
- focused on navy surfaces with neon-green action emphasis
- flatter and more controlled around icons, with subtle depth instead of glow halos

The app should not feel:

- purple-led
- glassy by default
- neon-glowing around every interactive element
- dependent on blurred icon glows to communicate emphasis

## Theme Strategy

The migration will be implemented in three layers.

### 1. Global Theme Tokens

Update `lib/core/theme/app_theme.dart` so the shared theme becomes the new default app language.

This layer will:

- remap primary, secondary, accent, surface, background, border, and text tokens to the approved palette
- align `ColorScheme` values with the new navy and neon system
- update shared gradients so primary actions stay neon-led instead of purple-led
- replace glow-derived helper values with flatter accent or subtle-shadow equivalents

This keeps most screens visually aligned without changing their structure.

### 2. Shared Visual Primitives

Update shared widgets that currently enforce the old glow-heavy style:

- `lib/widgets/zyntro_button.dart`
- `lib/widgets/zyntro_card.dart`
- `lib/widgets/premium_effects.dart`
- `lib/features/main/presentation/main_shell.dart`

This layer will:

- keep the same widget APIs and behavior
- restyle buttons to navy and neon treatments
- reduce or remove icon glow shadows
- convert icon containers to navy surfaces or subtle neon-tint fills
- restyle the bottom navigation and central workout action to match the approved palette

### 3. Targeted Screen Cleanup

Some screens use hard-coded old accent colors, gradients, or glow wrappers. These should receive a targeted cleanup pass only where needed to align them with the shared system.

Examples include:

- icon badges that still use explicit glow colors
- cards or action panels that still reference old purple gradients
- screen-specific hero or status surfaces that do not inherit the new theme correctly

This cleanup is visual only and should not alter layout logic or user flow.

## Icon Treatment

Icons should follow these rules after migration:

- active icons use neon green
- inactive icons use muted gray
- icons sit on navy surfaces or transparent backgrounds, depending on context
- icon emphasis comes from contrast, container shape, and scale, not glow
- icon-related pulsing glow wrappers should be removed or neutralized
- icon shadows, when needed, should be subtle dark depth rather than colored bloom

This applies to:

- bottom navigation icons
- action icons inside cards and tiles
- icon badges and stat chips
- button icons
- session, feed, settings, and profile icon containers

## Component Behavior Boundaries

The following must not change:

- route structure
- screen flow
- business logic
- Riverpod state behavior
- Firebase and service behavior
- form validation and submission logic
- session logic
- existing feature capabilities

The migration is successful only if the app behaves the same way and simply looks different.

## Expected File Scope

Primary expected files:

- `lib/core/theme/app_theme.dart`
- `lib/widgets/premium_effects.dart`
- `lib/widgets/zyntro_button.dart`
- `lib/widgets/zyntro_card.dart`
- `lib/features/main/presentation/main_shell.dart`

Secondary files will be touched only if they hard-code old colors or glow styling and do not update correctly through theme propagation.

## Verification Strategy

Verification should focus on visual-safety and regression control:

- run Flutter analysis on touched files
- run targeted widget or feature tests affected by theme refactors
- manually spot-check feed, session, social, profile, auth, notifications, and settings surfaces
- confirm that icons no longer show colored glow halos
- confirm that primary actions use neon green and dark surfaces use the approved navy stack
- confirm no interaction or navigation behavior changed during the migration

## Risks And Mitigation

### Risk: hard-coded legacy colors remain

Mitigation:

- search for old palette values and glow helpers after token migration
- patch only the visual references that still bypass shared theme tokens

### Risk: shared widget retheme causes uneven contrast

Mitigation:

- keep text and icon contrast anchored to the new navy and gray text system
- verify button, nav, chip, and card readability during manual spot checks

### Risk: glow removal makes some states unclear

Mitigation:

- preserve emphasis through neon accent color, border contrast, filled containers, and scale
- keep subtle depth shadows where useful, but do not reintroduce colored icon glow

## Final Design Decision

Use a token-first global retheme with a short targeted cleanup pass. This gives the app a consistent Figma-aligned visual system while keeping logic untouched and avoiding a risky screen-by-screen rewrite.
