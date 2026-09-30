# Tasks: Fix Onboarding & Login Flow

**Input**: Design documents from `specs/002-fix-onboarding-login/`
**Branch**: `002-fix-onboarding-login`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, quickstart.md ✓

**Tests**: Regression tests are included (required by constitution Principle III — auth routing changes must be regression-verified before cutover).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no incomplete-task dependencies)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: Setup

**Purpose**: Confirm scope and establish working context

- [x] T001 Read `specs/002-fix-onboarding-login/plan.md`, `data-model.md`, and `research.md` in full before touching any source file

---

## Phase 2: Foundational — Data Model Layer

**Purpose**: Add `trainingDaysPerWeek` through all clean-architecture layers. Must be complete before any user story implementation can begin.

**⚠️ CRITICAL**: US4 (Phase 3) cannot start until T002–T008 are all complete.

- [x] T002 [P] Add `trainingDaysPerWeek: int?` field to `UserProfileEntity` (with `copyWith` update) in `lib/features/auth/domain/entities/user_profile_entity.dart`
- [x] T003 [P] Add `trainingDaysPerWeek: int?` field + Firestore serialisation (`'trainingDaysPerWeek'` key, read as `int?`, write only when non-null) to `UserProfileModel` in `lib/features/auth/data/models/user_profile_model.dart`
- [x] T004 Add `trainingDaysPerWeek: int?` named parameter to `createUserProfile` in the `AuthRepository` interface in `lib/features/auth/domain/repositories/auth_repository.dart`
- [x] T005 Pass `trainingDaysPerWeek` through `AuthRepositoryImpl.createUserProfile` to the remote data source in `lib/features/auth/data/repositories/auth_repository_impl.dart` (depends on T004)
- [x] T006 Add `trainingDaysPerWeek: int?` to `AuthRemoteDataSource.createUserProfile`; add `if (trainingDaysPerWeek != null) 'trainingDaysPerWeek': trainingDaysPerWeek` to the Firestore write map in `lib/features/auth/data/datasources/auth_remote_data_source.dart` (depends on T004)
- [x] T007 Add `trainingDaysPerWeek: int?` named parameter to `AuthenticationUseCase.createUserProfile` and propagate to repository call in `lib/features/auth/domain/usecases/authentication_usecase.dart` (depends on T004)
- [x] T008 Add `trainingDaysPerWeek: int?` named parameter to `AuthController.createUserProfile` and propagate to use-case call in `lib/features/auth/presentation/providers/auth_controller.dart` (depends on T007)

T002 and T003 can run in parallel. T005, T006 can run in parallel after T004. T007 and T008 are sequential.

**Checkpoint**: Run `flutter analyze lib/features/auth/` — zero errors. All `createUserProfile` call sites must compile. Existing callers (e.g., `ProfileSetupPage`) must still compile with the new optional param (it is nullable/optional, so no call sites break).

---

## Phase 3: User Story 4 — Post-Signup Onboarding Saves Directly to Profile (P1)

**Goal**: `_finishOnboarding` calls `createUserProfile` with all collected state. The user is already authenticated at this point (post-signup), so data saves directly to Firestore.

**Independent Test**: Create a Firebase account in the app, manually navigate to `/onboarding`, complete all 5 steps, and tap "Start First Session." Verify that the Firestore `users/{uid}` document is created with `displayName`, `workoutPreference`, `avatarConfig`, and `trainingDaysPerWeek` matching what was entered. No Profile Setup screen should appear.

- [x] T009 [US4] Replace `storageServiceProvider` import with `authControllerProvider` and `authSessionProvider` imports in `lib/features/auth/presentation/onboarding_page.dart`
- [x] T010 [US4] Add private helper `WorkoutType _goalToWorkoutType(int index)` to `_OnboardingPageState` in `lib/features/auth/presentation/onboarding_page.dart` mapping indices 0→gym, 1→running, 2→hiit, 3→sports per `research.md`
- [x] T011 [US4] Replace `_finishOnboarding` body in `lib/features/auth/presentation/onboarding_page.dart`: call `ref.read(authControllerProvider).createUserProfile(displayName:, workoutPreference:, beginnerFlag: false, avatarConfig:, trainingDaysPerWeek:)` using `_nameController.text.trim()`, `_goalToWorkoutType(_selectedGoalIndex)`, `_avatarColors[_selectedColorIndex].toARGB32().toRadixString(16).padLeft(8, '0')`, and `_selectedDays`. Remove `setHasSeenOnboarding` and `context.go(AppRoutes.signUp)` calls. Add UID guard (`ref.read(authSessionProvider).valueOrNull?.id`) before calling createUserProfile.

T009, T010, T011 are sequential (same file).

**Checkpoint**: Hot-restart app. Authenticated user on `/onboarding` who completes all steps should have their Firestore profile created. Router should redirect to main automatically (no `context.go` needed).

---

## Phase 4: User Story 1 — New User First-Time Registration (P1)

**Goal**: Splash "Get Started" routes to signup (not onboarding). After signup, router routes the unauthenticated-now-authenticated user with no profile to `/onboarding`. After onboarding completes (Phase 3), router sends them to main.

**Independent Test**: Fresh install (or new Firebase account). Open app → "Get Started" → must land on signup screen. Create account → must land on onboarding (name step). Complete all onboarding steps → must land on main with profile populated. No Profile Setup screen should appear anywhere in this flow.

- [x] T012 [P] [US1] Change "Get Started" button `onPressed` from `context.go(AppRoutes.onboarding)` to `context.go(AppRoutes.signUp)` in `lib/features/auth/presentation/splash_page.dart`
- [x] T013 [P] [US2] In `lib/app/navigation/app_router.dart`: remove the `if (!storageService.hasSeenOnboarding)` redirect block (lines that check `hasSeenOnboarding` and redirect to `/onboarding` for logged-in users). Verify `storageService` is no longer read in the router redirect callback after removal.
- [x] T014 [US1] In `lib/app/navigation/app_router.dart`: in the incomplete-profile routing block, change the redirect target from `AppRoutes.profileSetup` to `AppRoutes.onboarding` (keep the `profileSetup` guard in the allowed-locations check so ProfileSetupPage remains accessible for recovery edge cases)

T012 and T013 can run in parallel (different files). T014 depends on T013 (same file).

**Checkpoint**: New-account flow: splash → "Get Started" → signup → onboarding → main. Returning user (complete profile) flow: splash → "Already have an account" → login → main (not onboarding).

---

## Phase 5: User Story 2 — Returning User Login on Any Device (P1)

**Goal**: A user with a complete profile on any device, including after clearing app data, logs in and lands directly on main — never routed to onboarding.

**Independent Test**: Log in with an account that has a complete profile (both `displayName` and `workoutPreference` set in Firestore). Simulate new device: clear SharedPreferences (`flutter clean` or wipe app data). Log in again. Must land on main, not on onboarding.

This story's routing bug is fixed by T013 (hasSeenOnboarding block removed). The tasks below verify correctness and add regression protection.

- [x] T015 [US2] In `lib/app/navigation/app_router.dart`: confirm `storageServiceProvider` is no longer `ref.watch`-ed inside `routerProvider` if it is only needed for the now-removed `hasSeenOnboarding` check. If `storageService` is used elsewhere in the router, leave the watch; if it's now unused in the router, remove the watch and import.
- [x] T016 [P] [US2] Update router redirect test in `test/app/navigation/app_route_locations_test.dart` (or equivalent router test file): add test case — logged-in user with `hasSeenOnboarding=false` AND `isProfileComplete=true` → router should redirect to `/` (main), not to `/onboarding`
- [x] T017 [P] [US2] Add test case to the router test file: logged-in user with `hasSeenOnboarding=false` AND `isProfileComplete=false` → router should redirect to `/onboarding`, not `/profile-setup`

T016 and T017 are parallelizable.

**Checkpoint**: `flutter test test/app/navigation/ --reporter compact` — all pass. Manual: clear app data, log in with profile-complete account → main.

---

## Phase 6: User Story 3 — Incomplete Profile Recovery (P2)

**Goal**: A user who created an account but abandoned onboarding is routed to `/onboarding` on next login. After completing onboarding, they reach main. The existing ProfileSetupPage is still accessible as a fallback.

**Independent Test**: Create a Firebase account (e.g., via Firebase console or signup screen without finishing onboarding). Log in. Must land on `/onboarding`. Complete all onboarding steps. Must land on main with profile populated.

The core recovery routing is already implemented by Phase 4 (T014). The tasks below complete US3 with verification and a regression test.

- [x] T018 [US3] Verify `app_router.dart` incomplete-profile guard still reads `state.matchedLocation != AppRoutes.profileSetup` (in addition to `/onboarding`) — ProfileSetupPage must remain reachable for legacy/edge recovery without triggering a redirect loop
- [x] T019 [P] [US3] Add router test case: logged-in user with `isProfileComplete=false` AND currently on neither `/onboarding` nor `/profile-setup` → must redirect to `/onboarding` (not `/profile-setup`)
- [x] T020 [P] [US3] Add router test case: logged-in user with `isProfileComplete=false` AND currently on `/profile-setup` → must NOT redirect (must return null, stay on profileSetup)

T019 and T020 are parallelizable.

**Checkpoint**: `flutter test test/app/navigation/ --reporter compact` — all pass. Manual: incomplete-profile account → login → lands on onboarding → complete → main.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Finalise the change, remove dead code, verify regression coverage.

- [x] T021 Remove `storageServiceProvider` import from `lib/features/auth/presentation/onboarding_page.dart` if it is no longer referenced after T009
- [x] T022 [P] Run `flutter analyze lib/ 2>&1 | Select-Object -First 80` and resolve all warnings in the changed files (`onboarding_page.dart`, `app_router.dart`, `splash_page.dart`, and all domain/data layer files changed in Phase 2)
- [x] T023 [P] Run `flutter test --reporter compact 2>&1 | tail -50` — all existing tests must still pass; no regressions in session, profile, or auth tests
- [ ] T024 Execute the four manual test scenarios from `specs/002-fix-onboarding-login/quickstart.md` and confirm all pass:
  1. New-user path (splash → signup → onboarding → main, profile populated)
  2. Returning-user path (login → main, no onboarding)
  3. New-device simulation (clear app data, login → main for complete-profile account)
  4. Incomplete-profile recovery (abandon onboarding, relaunch, login → onboarding → main)

**Checkpoint (Constitution Gate)**: All four quickstart scenarios pass. All router tests pass. `flutter analyze` clean. Ready for cutover.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundation)**: Depends on Phase 1 — **BLOCKS** Phases 3–6
- **Phase 3 (US4)**: Depends on Phase 2 completion
- **Phase 4 (US1)**: Depends on Phase 3 (onboarding must save before the new routing sends users there)
- **Phase 5 (US2)**: Shares Phase 4 router file — T015 depends on T013 being complete
- **Phase 6 (US3)**: Depends on Phase 4 (router change that routes to onboarding)
- **Phase 7 (Polish)**: Depends on all prior phases

### User Story Dependencies

- **US4 (P1)**: Can start after Foundation (Phase 2) — no dependency on US1/US2
- **US1 (P1)**: Can start after US4 (Phase 3) — requires save mechanism to exist before routing users there
- **US2 (P1)**: Router fix (T013) can run in parallel with splash fix (T012); verification tasks run after
- **US3 (P2)**: Can start after Phase 4 router change — ProfileSetupPage unchanged

### Parallel Opportunities

- T002 and T003 (Phase 2): different files, fully parallel ✅ **DONE**
- T005 and T006 (Phase 2): different files, parallel after T004 ✅ **DONE**
- T012 and T013 (Phase 4): different files, fully parallel
- T016 and T017 (Phase 5): different test cases, fully parallel
- T019 and T020 (Phase 6): different test cases, fully parallel
- T022 and T023 (Phase 7): different commands, fully parallel

---

## Parallel Example: Phase 2 (Foundation)

```text
# Stream 1 (entity + model):
T002 — UserProfileEntity + trainingDaysPerWeek  ✅ DONE
T003 — UserProfileModel + trainingDaysPerWeek   ✅ DONE

# Stream 2 (unblocked after T002/T003 compile):
T004 → T005 (repository interface → impl)       ✅ DONE
T004 → T006 (repository interface → remote data source) ✅ DONE
T004 → T007 → T008 (repository interface → use case → controller) ← NEXT
```

## Parallel Example: Phase 4 (Router + Splash)

```text
# Stream 1:
T012 — splash_page.dart: "Get Started" → /signup

# Stream 2:
T013 — app_router.dart: remove hasSeenOnboarding block
T014 — app_router.dart: change !isProfileComplete target (depends on T013, same file)
```

---

## Implementation Strategy

### MVP First (US4 + US1 — the new user path)

1. ~~Complete Phase 1: Setup~~ ✅
2. ~~Complete Phase 2: Foundation — CRITICAL blocker~~ ✅ (T002–T006 done; T007–T008 remaining)
3. Complete Phase 3: US4 — onboarding saves profile
4. Complete Phase 4: US1 — splash routes to signup + router fixes
5. **STOP and validate**: New-user path works end-to-end (quickstart scenario 1)

### Incremental Delivery

1. ~~Foundation (Phase 2) → compile-clean data model~~ ✅ partial
2. US4 (Phase 3) → onboarding saves to profile
3. US1 + US2 (Phase 4–5) → correct routing for new and returning users
4. US3 (Phase 6) → recovery path verified
5. Polish (Phase 7) → regression tests green, `flutter analyze` clean

---

## Notes

- `[P]` tasks = different files, no blocked dependencies — can be run in a parallel agent
- `[Story]` label maps each task to a specific user story for traceability
- `isProfileComplete` Firestore check is NOT changed — only checks `displayName` + `workoutPreference` (see `data-model.md` Decision 3)
- `StorageService.hasSeenOnboarding` remains in `StorageService` class — only the call in `_finishOnboarding` and the router's read of it are removed
- ProfileSetupPage is kept unchanged — it remains the legacy fallback for recovery (no tasks modify it)
- `storageService` may still be `ref.watch`-ed in the router for other purposes — T015 confirms whether it can be removed
