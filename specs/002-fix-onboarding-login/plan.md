# Implementation Plan: Fix Onboarding & Login Flow

**Branch**: `002-fix-onboarding-login` | **Date**: 2026-05-26 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/002-fix-onboarding-login/spec.md`

## Summary

Reorder the auth entry flow so that account creation (signup) precedes profile data collection (name, avatar, goal, training days). Fix the router so that profile-completion routing decisions are based exclusively on server-side account state — not on the local `hasSeenOnboarding` SharedPreferences flag. Eliminate the duplicate ProfileSetupPage path for new users by calling `createUserProfile` at the end of the post-signup onboarding steps.

**Correct flow after this change:**
```
Splash/Welcome → Signup → Post-signup onboarding (name → avatar → goal → days → done)
                       → createUserProfile() → Router detects isProfileComplete=true → Main
Login → Router detects isProfileComplete=true → Main
Login → Router detects isProfileComplete=false → Onboarding (recovery)
```

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x  
**Primary Dependencies**: firebase_auth, cloud_firestore, flutter_riverpod, go_router, shared_preferences  
**Storage**: Cloud Firestore (user profiles), SharedPreferences (local cache — routing no longer depends on it)  
**Testing**: flutter_test, mockito; existing router tests in `test/app/navigation/`  
**Target Platform**: iOS, Android  
**Performance Goals**: New-user full flow under 3 minutes (SC-001)  
**Constraints**: No breaking changes to existing user profile records; `trainingDaysPerWeek` is additive (nullable) to avoid marking existing accounts as incomplete  
**Scale/Scope**: Client-side routing and presentation layer — no backend changes required beyond adding a new optional Firestore field

## Constitution Check

### Pre-Design Gates

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Feature-Slice Scope | ✓ Pass | Changes scoped to auth/onboarding/routing; no other feature domains touched |
| II. Evidence-First Cutover | ✓ Pass | Regression evidence required for new-user path, returning-user login, recovery path |
| III. Security & Access Integrity | ✓ Pass | Auth routing changes require regression verification; removing local-storage gate strengthens integrity (no client bypass) |
| IV. Operational Safety | ✓ Pass | Client-side only; no downtime; rollback = revert; new Firestore field is additive |
| V. Independent Deliverability | ✓ Pass | Each user story independently testable per spec |

### Violations
None.

### Post-Design Re-check
See bottom of this document after Phase 1 completes.

## Project Structure

### Documentation (this feature)

```text
specs/002-fix-onboarding-login/
├── plan.md              ← this file
├── research.md          ← Phase 0 output
├── data-model.md        ← Phase 1 output
├── quickstart.md        ← Phase 1 output
└── tasks.md             ← Phase 2 output (/speckit-tasks — not created here)
```

### Source Code (affected files)

```text
lib/
├── app/navigation/
│   └── app_router.dart                     ← remove hasSeenOnboarding gate; fix incomplete-profile redirect
├── features/auth/
│   ├── presentation/
│   │   ├── splash_page.dart                ← "Get Started" routes to /signup not /onboarding
│   │   ├── onboarding_page.dart            ← _finishOnboarding calls createUserProfile; remove setHasSeenOnboarding
│   │   └── signup_page.dart               ← no route change needed; already correct destination
│   ├── domain/
│   │   ├── entities/user_profile_entity.dart    ← add trainingDaysPerWeek: int?
│   │   └── usecases/authentication_usecase.dart ← add trainingDaysPerWeek param to createUserProfile
│   ├── data/
│   │   ├── models/user_profile_model.dart       ← add trainingDaysPerWeek field + Firestore serialisation
│   │   ├── datasources/auth_remote_data_source.dart ← add trainingDaysPerWeek to createUserProfile
│   │   └── repositories/auth_repository_impl.dart   ← pass through trainingDaysPerWeek
│   └── domain/repositories/auth_repository.dart     ← add trainingDaysPerWeek to interface

test/
├── app/navigation/app_route_locations_test.dart     ← update router redirect tests
└── features/auth/presentation/                      ← update onboarding + splash tests
```

## Phase 0: Research

See [research.md](research.md) for full findings.

**All NEEDS CLARIFICATION items resolved:**
- avatarConfig string format: `"0xFF{RRGGBB}"` — matches Flutter Color.value hex pattern
- WorkoutType mapping from onboarding goals: gym / running / hiit / sports
- trainingDaysPerWeek: additive nullable field; not added to isProfileComplete check
- Router refactor: remove `hasSeenOnboarding` block; change `!isProfileComplete` target from `/profile-setup` to `/onboarding`

## Phase 1: Design & Contracts

See [data-model.md](data-model.md) for entity changes.

**No external contracts.** This is a mobile app; there are no public APIs, CLI schemas, or library interfaces exposed to callers outside the app. Firestore schema changes are documented in data-model.md.

### Router Logic Change (before / after)

**Before** (current — broken):
```
[logged in]
  → if !storageService.hasSeenOnboarding → /onboarding  ← BUG: device-local, breaks new devices
  → if !isProfileComplete → /profile-setup               ← BUG: shows duplicate form
  → if isProfileComplete on auth page → /
```

**After** (fixed):
```
[logged in]
  → if !isProfileComplete → /onboarding                  ← unified recovery: onboarding handles both new + recovery
  → if isProfileComplete on auth page → /
  (hasSeenOnboarding check removed entirely for logged-in users)
```

**SplashPage CTA change:**
```
Before: "Get Started"  →  context.go(AppRoutes.onboarding)
After:  "Get Started"  →  context.go(AppRoutes.signUp)
```

**OnboardingPage `_finishOnboarding` change:**
```
Before:
  ref.read(storageServiceProvider).setHasSeenOnboarding(true);
  context.go(AppRoutes.signUp);

After:
  await ref.read(authControllerProvider).createUserProfile(
    displayName: _nameController.text.trim(),
    workoutPreference: _mapGoalToWorkoutType(_selectedGoalIndex),
    beginnerFlag: false,
    avatarConfig: _avatarColorToConfig(_avatarColors[_selectedColorIndex]),
    trainingDaysPerWeek: _selectedDays,
  );
  // Router will redirect to main automatically when isProfileComplete becomes true
  // No explicit navigation call needed
```

### WorkoutType mapping (onboarding index → enum)

| Goal index | Label | WorkoutType |
|---|---|---|
| 0 | Build Strength 💪 | `WorkoutType.gym` |
| 1 | Improve Cardio 🏃 | `WorkoutType.running` |
| 2 | Body Composition 🔥 | `WorkoutType.hiit` |
| 3 | Compete 🏆 | `WorkoutType.sports` |

### avatarConfig encoding

`Color.value.toRadixString(16).padLeft(8, '0')` → e.g. `"ffc8ff00"` for lime.
Stored in Firestore as `avatarConfig: "ffc8ff00"`. Consistent with how Flutter Color is already serialised in other parts of the app.

### Constitution Post-Design Re-check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Feature-Slice Scope | ✓ Pass | Only auth/onboarding/routing files changed |
| II. Evidence-First Cutover | ✓ Pass | tasks.md will include explicit regression scenarios |
| III. Security & Access Integrity | ✓ Pass | No security regressions; auth state unchanged; routing is more secure (server-side only) |
| IV. Operational Safety | ✓ Pass | Firestore field addition is additive; no migration needed |
| V. Independent Deliverability | ✓ Pass | Stories remain independently implementable |

## Complexity Tracking

No constitution violations to justify.
