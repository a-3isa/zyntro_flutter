# Tasks: Premium UI/UX Redesign

**Input**: Design documents from `specs/003-premium-ui-redesign/`
**Branch**: `003-premium-ui-redesign`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, quickstart.md ✓

**Tests**: No test tasks generated — this is a UI/visual feature; acceptance is via quickstart.md manual scenarios and code-search audits (SC-002, SC-003).

**Organization**: Tasks are grouped by user story. US1 (typography) is the P1 blocker — it unblocks everything. US3 (token unification) should complete before US4 (screen polish) to avoid polishing with the wrong tokens.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no incomplete-task dependencies)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: Setup

**Purpose**: Establish working context before touching any source file

- [x] T001 Read `specs/003-premium-ui-redesign/plan.md`, `research.md`, and `data-model.md` in full before touching any source file

---

## Phase 2: Foundation — AppTextStyles + Text Scale Cap

**Purpose**: Create the centralised type scale class and apply the text-scale cap. These two artefacts MUST exist before any US1 typography migration can begin.

**⚠️ CRITICAL**: US1 tasks T006–T020 cannot begin until T002–T005 are complete.

- [x] T002 Create `lib/core/theme/app_text_styles.dart` with the `AppTextStyles` class containing 8 static `TextStyle` getters: `display` (Syne 48sp w700 ls-0.5 h1.1), `h1` (Syne 40sp w700 ls-0.3 h1.15), `h2` (Syne 32sp w600 ls0 h1.2), `h3` (Syne 24sp w600 ls0 h1.25), `bodyLarge` (Outfit 16sp w500 ls0 h1.5), `body` (Outfit 14sp w400 ls0 h1.5), `label` (Outfit 14sp w600 ls0.1 h1.2), `caption` (Outfit 12sp w400 ls0.2 h1.4). All getters are colour-agnostic (no `color:` argument). Class has a private constructor `AppTextStyles._()`.

- [x] T003 Update `AppTheme.darkTheme` `textTheme` in `lib/core/theme/app_theme.dart` to delegate slots to `AppTextStyles`: `displayLarge` → `AppTextStyles.display.copyWith(color: AppColors.textV2Primary)`, `displayMedium` → `AppTextStyles.h1` + colour, `headlineLarge` → `AppTextStyles.h2` + colour, `headlineMedium`/`titleLarge` → `AppTextStyles.h3` + colour, `titleMedium`/`bodyLarge` → `AppTextStyles.bodyLarge` + colour, `bodyMedium` → `AppTextStyles.body` + secondary colour, `labelLarge` → `AppTextStyles.label` + colour, `labelSmall` → `AppTextStyles.caption` + secondary colour. (Depends on T002.)

- [x] T004 Update `AppTheme.lightTheme` `textTheme` in `lib/core/theme/app_theme.dart` with the same slot mapping as T003 but using `AppColors.textV2PrimaryLight` / `textV2SecondaryLight` colour variants. (Depends on T002, sequential with T003 — same file.)

- [x] T005 Find the root `MaterialApp` widget (search `lib/` for `MaterialApp(` — likely `lib/app/app.dart` or `lib/main.dart`) and add a `builder:` callback wrapping `child` with `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child!)`. If a `builder:` already exists, nest the clamp wrapper inside it. (Parallel to T003/T004 — different file.)

**Checkpoint**: Run `flutter analyze lib/core/theme/ 2>&1 | Select-Object -First 40` — zero errors. `AppTextStyles` is importable.

---

## Phase 3: User Story 1 — Typography Audit & Fix (Priority: P1)

**Goal**: Eliminate font distortion across the entire app. Fix the 7 `FontWeight.w900` instances on Syne (root cause of "stretched" text). Migrate all 36 widget files from inline `GoogleFonts.syne/outfit()` calls to `AppTextStyles` getters.

**Independent Test** (quickstart.md Scenario 1 + 2):
1. Open the app on any device — the "zyntro" wordmark and rep counter numbers no longer appear stretched or artificially widened.
2. Code search: `rg "GoogleFonts\.(syne|outfit)\(" lib/ --type dart -l` returns only `app_text_styles.dart` and `app_theme.dart`.

### Fix w900 Instances (Root Cause — highest priority)

- [x] T006 [P] [US1] In `lib/features/session/presentation/session_room_page.dart`, replace all 4 occurrences of `FontWeight.w900` (lines ~1713, 1760, 2088, 2873) with `FontWeight.w700`. These are all on Syne font — w900 exceeds Syne's maximum native weight (w800) and causes synthesised glyph widening.

- [x] T007 [P] [US1] In `lib/features/session/presentation/widgets/rep_counter_screen.dart`, replace both occurrences of `FontWeight.w900` (lines ~100, 110) with `FontWeight.w700` on Syne. Same synthetic-widening root cause as T006.

- [x] T008 [P] [US1] In `lib/widgets/streak_card.dart`, replace the `FontWeight.w900` occurrence (line ~156) with `FontWeight.w700` on Syne.

T006, T007, T008 are parallel — different files.

### Auth Screens Migration

- [x] T009 [P] [US1] In `lib/features/auth/presentation/splash_page.dart` and `lib/features/auth/presentation/onboarding_page.dart`: replace every `GoogleFonts.syne(...)` and `GoogleFonts.outfit(...)` call with the appropriate `AppTextStyles` getter (e.g., wordmark → `AppTextStyles.display`, step headings → `AppTextStyles.h1`, body copy → `AppTextStyles.body`). Add `import 'package:zyntro_flutter/core/theme/app_text_styles.dart';`. Keep `.copyWith(color: ...)` for any colour overrides.

- [x] T010 [P] [US1] Migrate `lib/features/auth/presentation/login_page.dart`, `lib/features/auth/presentation/signup_page.dart`, `lib/features/auth/presentation/forgot_password_page.dart`, and `lib/features/auth/presentation/profile_setup_page.dart` to `AppTextStyles` (same approach as T009).

T009 and T010 are parallel — different files.

### Feed & Post Screens Migration

- [x] T011 [P] [US1] Migrate `lib/features/feed/presentation/feed_page.dart` and `lib/features/feed/presentation/post_detail_page.dart` to `AppTextStyles`.

### Profile Screens Migration

- [x] T012 [P] [US1] Migrate all profile screens to `AppTextStyles`: `lib/features/profile/presentation/profile_page.dart`, `edit_profile_page.dart`, `workout_history_page.dart`, `connections_list_page.dart`, `user_posts_page.dart`, `follow_requests_page.dart`.

T011 and T012 are parallel — different files.

### Session Screens Migration

- [x] T013 [P] [US1] Migrate `lib/features/session/presentation/session_room_page.dart` to `AppTextStyles`. (w900 already fixed in T006 — this task replaces the remaining inline GoogleFonts calls.) Also migrate `session_page.dart`, `start_session_page.dart`, `gym_session_setup_page.dart`, and `recap_page.dart`.

### Session Widgets Migration

- [x] T014 [P] [US1] Migrate session widgets to `AppTextStyles`: `lib/features/session/presentation/widgets/active_turn_screen.dart`, `rep_counter_screen.dart` (w900 already fixed in T007), `parallel_cardio_view.dart`, `parallel_gym_view.dart`, `waiting_turn_screen.dart`.

T013 and T014 are parallel — different files.

### Shared Widgets Migration

- [x] T015 [P] [US1] Migrate `lib/widgets/streak_card.dart` (w900 already fixed in T008) and `lib/widgets/celebration_overlay.dart` to `AppTextStyles`.

### Settings, Notifications & Utility Screens Migration

- [x] T016 [P] [US1] Migrate all settings pages to `AppTextStyles`: `lib/features/settings/presentation/settings_page.dart`, `terms_of_service_page.dart`, `privacy_policy_page.dart`, `community_guidelines_page.dart`, `change_password_page.dart`, `blocked_users_page.dart`, `privacy_settings_page.dart`, `delete_account_page.dart`, `change_email_page.dart`.

- [x] T017 [P] [US1] Migrate `lib/features/notifications/presentation/notifications_page.dart`, `notification_preferences_page.dart`, `lib/features/moderation/presentation/moderation_queue_page.dart`, and `lib/features/social/presentation/social_page.dart` to `AppTextStyles`.

T015, T016, T017 are parallel — different files.

**Checkpoint (US1)**: Run `flutter analyze lib/ 2>&1 | Select-Object -First 80` — zero errors. Run `rg "GoogleFonts\.(syne|outfit)\(" lib/ --type dart -l` — output contains ONLY `lib/core/theme/app_text_styles.dart` and `lib/core/theme/app_theme.dart`.

---

## Phase 4: User Story 3 — Design Token Unification (Priority: P2)

**Goal**: Retire all legacy navy/neonGreen token usages. Update `AppColors` aliases and gradient presets so the entire app uses v2 true-black + acid-lime tokens.

**Why US3 before US2**: US3 fixes the token layer that US2 and US4 inspect for visual correctness.

**Independent Test** (quickstart.md Scenario 3 + 6):
- Code search: `rg "AppColors\.(navy900|navy800|navy700|neonGreen|neonGreenHover)" lib/ --type dart -l` — only `app_theme.dart` (constant declarations).
- Visual: Navigate through all 5 key screens — all backgrounds are true-black (#080808), no navy tint visible.

- [x] T018 [US3] In `lib/core/theme/app_theme.dart`, update the `AppColors` alias assignments: `primary = accentLime` (was neonGreen), `primaryDark = accentLimeDim` (was neonGreenHover), `action = accentLime`, `actionDark = accentLimeDim`, `warmBackground = surfaceV2Elevated` (was navy700), `warmBorder = accentLime` (was neonGreen), `warmAccent = textV2Secondary` (was gray300). Also update gradient presets: `primaryGradient = [accentLime, accentLimeDim]`, `secondaryGradient = [surfaceV2Elevated, surfaceV2]`, `premiumGradient = [surfaceV2, surfaceV2Elevated]`, `motivationalGradient = [surfaceV2Elevated, accentLime]`, `achievementGradient = [surfaceV2, accentLime]`, `streakGradient = [surfaceV2Elevated, surfaceV2, accentLimeDim]`, `cardGradient = [surfaceV2, surfaceV2Elevated]`, `splashGradient = [backgroundV2, surfaceV2, surfaceV2Elevated, surfaceV2Active]`. Keep the constant declarations (`navy900`, `neonGreen`, etc.) in place but add `@Deprecated` annotations.

- [x] T019 [P] [US3] In `lib/widgets/reaction_buttons.dart`: replace any direct references to `AppColors.navy900`, `navy800`, `navy700`, `neonGreen`, or `neonGreenHover` with their v2 equivalents (`backgroundV2`, `surfaceV2`, `surfaceV2Elevated`, `accentLime`, `accentLimeDim`).

- [x] T020 [P] [US3] In `lib/widgets/premium_effects.dart`: same legacy token replacement as T019.

T019 and T020 depend on T018 (token aliases established) and are parallel with each other — different files.

**Checkpoint (US3)**: Run `rg "AppColors\.(navy900|navy800|navy700|neonGreen|neonGreenHover)" lib/ --type dart -l` — output is ONLY `lib/core/theme/app_theme.dart`. Run `flutter analyze lib/ 2>&1 | Select-Object -First 80` — zero errors.

---

## Phase 5: User Story 2 — Premium Visual Elevation (Priority: P1)

**Goal**: Ensure all interactive elements across the 5 key screens have visible pressed states, consistent card padding (≥16pt), and consistent section spacing.

**Independent Test** (quickstart.md Scenario 5):
- Tap every button and card on the 5 key screens — each shows a visible scale-down (0.96× buttons, 0.98× cards) within 100ms.
- Cards on feed, session setup, and profile have ≥16pt padding on all sides with no text touching the edge.

- [x] T021 [US2] Audit `lib/features/feed/presentation/feed_page.dart`: verify feed post cards use `InkWell`/`GestureDetector` with a scale animation or `AppAnimations.cardPressScale` (0.98×). If missing, add an `AnimatedScale` or `GestureDetector` with `onTapDown`/`onTapUp` callbacks that animate to `AppAnimations.cardPressScale` using `AppDurations.fast` duration. Verify card padding is `AppSpacing.lg` (16pt) on all sides.

- [x] T022 [US2] Audit `lib/features/profile/presentation/profile_page.dart`: verify stat cards and history items have pressed states (0.98×) and ≥16pt internal padding. Accent colour (`accentLime`) should appear only on primary stats and active indicators — remove any decorative overuse of lime.

- [x] T023 [US2] Audit `lib/features/session/presentation/gym_session_setup_page.dart`: verify the primary CTA button ("Start Session" or equivalent) uses `AppAnimations.buttonPressScale` (0.96×) press animation. Verify section spacing between form groups uses `AppSpacing.xl` (24pt).

- [x] T024 [US2] Audit `lib/features/session/presentation/session_room_page.dart`: verify the primary action button (end set / switch turn) is visually prominent (accentLime background, full-width or large tap target). Verify it has 0.96× press animation.

- [x] T025 [US2] Audit `lib/features/auth/presentation/onboarding_page.dart`: verify the "Next"/"Get Started" CTA button on each step uses `AppAnimations.buttonPressScale` (0.96×). Verify step card/container padding is ≥16pt.

**Checkpoint (US2)**: Tap every button and card on the 5 key screens — visible press response on each.

---

## Phase 6: User Story 4 — Screen-Level Polish: Key Screens (Priority: P2)

**Goal**: Targeted layout improvements on the 5 key screens beyond what the token and typography fixes provide.

**Independent Test** (quickstart.md Scenario 6):
- A returning user walks the full flow (onboarding → session → feed → profile) and the experience feels seamless — no visual jarring, inconsistent spacing, or layout shifts.

- [x] T026 [US4] Polish `lib/features/auth/presentation/onboarding_page.dart`: ensure all 5 onboarding steps share a consistent visual template — same header vertical position, same progress indicator widget and style, same primary CTA button vertical position at the bottom. Steps that differ from the template should be adjusted to match.

- [x] T027 [US4] Polish `lib/features/feed/presentation/feed_page.dart`: audit card layout for consistency across all post types (text-only, with image, with workout stats). Each post card must use the same padding (`AppSpacing.lg` all sides), same corner radius (`AppBorderRadius.xl`), and same inter-card gap (`AppSpacing.md`). Fix any layout shifts between post types.

- [x] T028 [US4] Polish `lib/features/session/presentation/session_room_page.dart`: the primary action button (end set / complete turn) must always be the visually largest, most prominent element in the action area. Ensure it has an `accentLime` background, sufficient height (≥56pt), and is not visually buried by secondary controls. Apply `AppSpacing.xl` between major screen sections.

- [x] T029 [US4] Polish `lib/features/profile/presentation/profile_page.dart`: organise stat data into visually distinct groups with `AppSpacing.xl` between groups. Ensure accent colour is used only for primary stats and active indicators. Stat labels use `AppTextStyles.caption`; stat values use `AppTextStyles.h3`.

**Checkpoint (US4)**: Walk the full user flow — onboarding steps feel templated, feed cards look consistent, session action is prominent, profile is well-organised.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final verification pass, code search audits, and analysis clean-up.

- [x] T030 Run `flutter analyze lib/ 2>&1 | Select-Object -First 80` — zero errors in all changed files.

- [x] T031 [P] Run typography code-search audit (quickstart.md Scenario 2): `rg "GoogleFonts\.(syne|outfit)\(" lib/ --type dart -l`. Output must contain ONLY `lib/core/theme/app_text_styles.dart` and `lib/core/theme/app_theme.dart`. If any other file appears, fix it.

- [x] T032 [P] Run token code-search audit (quickstart.md Scenario 3): `rg "AppColors\.(navy900|navy800|navy700|neonGreen|neonGreenHover)" lib/ --type dart -l`. Output must contain ONLY `lib/core/theme/app_theme.dart`. Also run raw hex search: `rg "0xFF0A0E27|0xFF151B3D|0xFF1E2749|0xFF39FF14|0xFF2EE00F" lib/ --type dart -l`. Output must be empty.

- [x] T033 Execute quickstart.md manual scenarios 1, 4, 5, 6, and 7 on a physical device or simulator. Confirm all pass. Mark results in the quickstart.md file next to each scenario.

T030, T031, T032 are parallel. T033 depends on all prior phases.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundation)**: Depends on Phase 1 — **BLOCKS** Phases 3–6
- **Phase 3 (US1)**: Depends on Phase 2 (AppTextStyles must exist)
- **Phase 4 (US3)**: Depends on Phase 2; can start in parallel with Phase 3 (different files)
- **Phase 5 (US2)**: Depends on Phase 3 (typography migration) and Phase 4 (token unification) to avoid auditing with wrong tokens
- **Phase 6 (US4)**: Depends on Phase 5
- **Phase 7 (Polish)**: Depends on all prior phases

### User Story Dependencies

- **US1 (P1)**: Start after Foundation (Phase 2)
- **US3 (P2)**: Can start after Foundation — no dependency on US1
- **US2 (P1)**: Start after US1 and US3 are both complete
- **US4 (P2)**: Start after US2

### Key Parallel Opportunities

- T006, T007, T008 (w900 fixes): parallel — different files ✅
- T009–T017 (typography migration): all parallel — different file groups ✅
- T019 and T020 (legacy token files): parallel — different files ✅
- T021–T025 (US2 audits): parallel — different key screens ✅
- T031 and T032 (code-search audits): parallel — read-only ✅

---

## Parallel Example: Phase 3 (US1 — Typography Migration)

```text
# Stream 1 (auth screens):
T009 — splash_page + onboarding_page
T010 — login/signup/forgot_password/profile_setup

# Stream 2 (feed + profile):
T011 — feed_page + post_detail_page
T012 — all profile/* pages

# Stream 3 (session):
T013 — session_room (w900 fixed) + session_page + start/gym_setup/recap
T014 — session widgets (rep_counter w900 fixed) + parallel views

# Stream 4 (utility):
T015 — streak_card + celebration_overlay
T016 — all settings/* pages
T017 — notifications + moderation + social
```

All 4 streams can run simultaneously after T002 (AppTextStyles) is complete.

---

## Implementation Strategy

### MVP First (US1 only — typography fix)

1. Complete Phase 1 (Setup) and Phase 2 (Foundation) — creates AppTextStyles
2. Fix the 7 w900 instances (T006–T008) — immediately removes root cause of "stretched" text
3. Migrate the 5 key screens (T009 splash/onboarding, T011 feed, T012 profile, T013 session) — covers the highest-traffic screens
4. **STOP and validate**: Open the app — confirm text no longer looks stretched on key screens
5. Continue migrating remaining files (T010, T014–T017) for SC-002 compliance

### Incremental Delivery

1. Foundation (Phase 2) → AppTextStyles class + text scale cap ← compile check
2. US1 w900 fixes (T006–T008) → root cause resolved ← visible improvement
3. US1 full migration (T009–T017) → SC-002 achieved (zero ad-hoc font calls) ← code audit
4. US3 (T018–T020) → SC-003 achieved (zero legacy tokens) ← code audit
5. US2 (T021–T025) → pressed states + layout verified ← SC-005
6. US4 (T026–T029) → key screen polish ← SC-004
7. Phase 7 (T030–T033) → full QA pass ← all SCs verified

---

## Notes

- `[P]` tasks = different files, no blocked dependencies — safe to run in parallel
- `[Story]` label maps each task to a user story for traceability
- All typography migration tasks (T009–T017) are the same mechanical operation: find `GoogleFonts.syne/outfit(fontSize: X, fontWeight: Y, ...)` → replace with `AppTextStyles.<level>.copyWith(color: <existing_color>)`; preserve any `.copyWith(color: ...)` already present
- The w900 → w700 fixes (T006–T008) are 3-line changes each — do these first for immediate visual impact
- `app_theme.dart` itself is NOT migrated to AppTextStyles (it IS the source); only its `textTheme` slots delegate to AppTextStyles (T003/T004)
- After T018 updates the AppColors aliases, widgets that reference `AppColors.primary` or `AppColors.action` will automatically get accentLime — no per-widget change needed for those
