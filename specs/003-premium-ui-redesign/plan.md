# Implementation Plan: Premium UI/UX Redesign

**Branch**: `003-premium-ui-redesign` | **Date**: 2026-05-26 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/003-premium-ui-redesign/spec.md`

---

## Summary

Fix the "stretched/heavy" font rendering caused by `FontWeight.w900` on Syne (which only supports 400–800) in 7 widget locations, and the secondary over-heaviness from w800 used too broadly. Create a centralised `AppTextStyles` class and migrate all 37 files that currently call `GoogleFonts.syne/outfit` inline. Retire legacy navy/neonGreen token usages from the 3 non-theme files that still reference them and update `AppColors` aliases to point to v2 tokens. Apply targeted layout polish to the 5 key screens: feed, session setup, active session, profile, and onboarding.

---

## Technical Context

**Language/Version**: Dart / Flutter SDK ^3.10.4 (Material 3, `useMaterial3: true`)
**Primary Dependencies**: `google_fonts` (Syne + Outfit via Google Fonts CDN/asset), `flutter_riverpod ^2.6.1`, `go_router ^14.8.1`
**Storage**: N/A — pure UI/design change; no persistence layer modifications
**Testing**: `flutter test --reporter compact`; manual visual QA on device
**Target Platform**: iOS + Android (dark-mode primary)
**Performance Goals**: No regressions; `flutter analyze` clean; animation frame rate unchanged
**Constraints**: Navigation structure unchanged; no new routes; font files not swapped — existing Google Fonts package provides variable fonts
**Scale/Scope**: 37 files with inline typography, 3 files with legacy token usage, 5 key screens for layout polish

---

## Constitution Check

### Pre-Design Gate

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Feature-Slice Scope Discipline | ✓ PASS | Scope bounded to theme layer + 37 widget files; no data model, routing, or business logic changes |
| II. Evidence-First Cutover | ✓ PASS | 7 quickstart scenarios define acceptance evidence; SC-001–SC-006 are measurable |
| III. Security and Access Integrity | ✓ N/A | No auth or access changes |
| IV. Operational Safety and Reversibility | ✓ PASS | Pure UI change; revert = revert the PR; no downtime concern |
| V. Independent Deliverability | ✓ PASS | US1 (typography fix) is independently deliverable before US2–US4 |

No gate violations. Proceeding to Phase 0 research.

### Post-Design Gate (re-check)

All gates still pass. Design introduces no new security surface, no new data persistence, and no routing changes. Regression evidence defined in `quickstart.md`.

---

## Project Structure

### Documentation (this feature)

```text
specs/003-premium-ui-redesign/
├── plan.md          ← this file
├── research.md      ✓ created
├── data-model.md    ✓ created
├── quickstart.md    ✓ created
└── tasks.md         ← created by /speckit-tasks
```

### Source Code (affected files)

```text
lib/core/theme/
├── app_theme.dart          ← update AppColors aliases, textTheme slots, gradient presets
└── app_text_styles.dart    ← NEW: centralised type scale

lib/features/
├── auth/presentation/
│   ├── splash_page.dart
│   ├── onboarding_page.dart
│   ├── login_page.dart
│   ├── signup_page.dart
│   ├── forgot_password_page.dart
│   └── profile_setup_page.dart
├── feed/presentation/
│   ├── feed_page.dart
│   └── post_detail_page.dart
├── profile/presentation/
│   ├── profile_page.dart
│   ├── edit_profile_page.dart
│   ├── workout_history_page.dart
│   ├── connections_list_page.dart
│   └── user_posts_page.dart
├── session/presentation/
│   ├── session_room_page.dart       ← also fix 4× w900 instances
│   ├── session_page.dart
│   ├── start_session_page.dart
│   ├── gym_session_setup_page.dart
│   ├── recap_page.dart
│   ├── session_invite_acceptance_page.dart
│   └── widgets/
│       ├── active_turn_screen.dart
│       ├── rep_counter_screen.dart  ← also fix 2× w900 instances
│       ├── parallel_cardio_view.dart
│       ├── parallel_gym_view.dart
│       └── waiting_turn_screen.dart
├── settings/presentation/          ← all settings pages (token + typography only)
├── notifications/presentation/     ← token + typography only
├── moderation/presentation/        ← token + typography only
└── social/presentation/
    └── social_page.dart

lib/widgets/
├── streak_card.dart                ← also fix 1× w900 instance
├── reaction_buttons.dart           ← legacy token migration
├── premium_effects.dart            ← legacy token migration
└── celebration_overlay.dart
```

---

## Phase 0: Research

**Status**: COMPLETE — see [research.md](research.md)

Key findings:
1. Root cause of "stretched" text: `FontWeight.w900` on Syne (supports 400–800 only) in 7 locations → synthetic glyph widening
2. Secondary cause: w800 used broadly; w700 is the appropriate cap for display text
3. `AppTextStyles` class pattern: new file, colour-agnostic getters, delegates to AppTheme.textTheme
4. Text scale cap: `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)` at `MaterialApp.builder`
5. Legacy token scope: only 3 widget files outside `app_theme.dart`

---

## Phase 1: Design & Contracts

**Status**: COMPLETE — see [data-model.md](data-model.md) and [quickstart.md](quickstart.md)

### Design Token Model
Defined in data-model.md:
- `AppTextStyles` type scale: 8 named levels (display, h1, h2, h3, bodyLarge, body, label, caption)
- `AppColors` alias updates: 7 aliases migrated to v2 tokens
- Gradient preset replacements: 7 gradients updated
- Component specs for Card, Primary Button, and section spacing

### Interface Contracts
This feature has no external-facing API contracts. The `AppTextStyles` class is an internal library; widgets reference it directly.

### Integration Scenarios
Defined in quickstart.md:
- 7 manual scenarios covering SC-001 through SC-006
- Includes code-search-automatable checks (Scenarios 2 and 3)

---

## Implementation Order (for /speckit-tasks)

### User Story Priority

| Story | Priority | Scope |
|-------|----------|-------|
| US1 — Typography Audit & Fix | P1 | Create AppTextStyles, fix w900 instances, migrate 37 files |
| US2 — Premium Visual Elevation | P1 | Pressed states, card padding, section spacing on 5 key screens |
| US3 — Design Token Unification | P2 | AppColors alias updates, gradient presets, retire 3 widget files |
| US4 — Screen-Level Polish | P2 | Targeted layout improvements on 5 key screens |

### Recommended Implementation Order

1. **Foundation** (blocks all stories):
   - Create `app_text_styles.dart`
   - Update `AppTheme.textTheme` slots to delegate to AppTextStyles
   - Add `MediaQuery.withClampedTextScaling` wrapper in MaterialApp.builder

2. **US1** (highest user impact — fix the root cause first):
   - Fix the 7 w900 → w700 instances in streak_card, session_room_page, rep_counter_screen
   - Migrate all 37 inline GoogleFonts files to AppTextStyles (can be parallelised by feature domain)

3. **US3** (systemic — unblocks US2/US4 visual consistency checks):
   - Update AppColors aliases and gradient presets in app_theme.dart
   - Migrate reaction_buttons.dart and premium_effects.dart

4. **US2** (polish depends on correct tokens being in place):
   - Verify/add pressed states on buttons and cards
   - Verify card padding ≥16pt, consistent corner radii

5. **US4** (final pass on key screens):
   - Onboarding visual template consistency
   - Feed card layout consistency
   - Active session CTA prominence
   - Profile data grouping and accent usage

### Parallel Opportunities

- Typography migration (US1) across different feature domains can run in parallel agents:
  - Stream A: `auth/` presentation files
  - Stream B: `feed/` + `profile/` presentation files
  - Stream C: `session/` presentation files + widgets (also handles w900 fixes)
  - Stream D: `settings/` + `notifications/` + `moderation/` + `social/` (token + typography only)

---

## Complexity Tracking

No constitution violations. No complexity justifications required.
