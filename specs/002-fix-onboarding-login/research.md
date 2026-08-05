# Research: Fix Onboarding & Login Flow

**Date**: 2026-05-26 | **Branch**: `002-fix-onboarding-login`

## Decision 1: avatarConfig Storage Format

**Decision**: Store avatar color as an 8-character lowercase hex string of `Color.value` — e.g., `"ffc8ff00"` for `Color(0xFFC8FF00)`.

**Rationale**: `Color.value` is a 32-bit ARGB integer. Converting with `color.value.toRadixString(16).padLeft(8, '0')` is deterministic and reversible (`Color(int.parse(s, radix: 16))`). The existing `createUserProfile` already accepts an `avatarConfig: String?` field in Firestore with no prescribed format — no schema migration needed.

**Alternatives considered**:
- CSS hex string `"#C8FF00"` — lossy (drops alpha channel); harder to reconstruct exact Color value
- JSON object `{"r":200,"g":255,"b":0}` — more bytes, no benefit for a single color value
- Index integer `0–7` — tight coupling to the onboarding color list; breaks if list changes

---

## Decision 2: WorkoutType Mapping from Onboarding Goal Options

**Decision**:

| Onboarding label | WorkoutType enum |
|---|---|
| Build Strength 💪 | `WorkoutType.gym` |
| Improve Cardio 🏃 | `WorkoutType.running` |
| Body Composition 🔥 | `WorkoutType.hiit` |
| Compete 🏆 | `WorkoutType.sports` |

**Rationale**: `WorkoutType.gym` is the only `strength` category type, matching "Build Strength." `WorkoutType.running` is the canonical cardio type. `WorkoutType.hiit` (`category: 'mixed'`) best represents body composition training which combines resistance and high-intensity work. `WorkoutType.sports` (`category: 'mixed'`) most accurately represents competitive/sports training. No new enum values are needed.

**Alternatives considered**:
- Map "Compete" → `WorkoutType.other` — accurate but loses semantics; `sports` is more precise
- Map "Body Composition" → `WorkoutType.gym` — loses the metabolic conditioning intent

---

## Decision 3: trainingDaysPerWeek Field — Add or Skip

**Decision**: Add `trainingDaysPerWeek: int?` as a nullable, optional field to `UserProfileEntity`, `UserProfileModel`, and Firestore schema. Do NOT add it to the `isProfileComplete` check.

**Rationale**: The spec requires saving this value (it's part of the data the user enters). However, marking existing accounts as profile-incomplete would break returning users who never saw this field. Making it nullable and excluding it from `isProfileComplete` keeps the change purely additive. Future work can promote it to required if needed.

**Alternatives considered**:
- Add to `isProfileComplete` check — would mark all existing users as incomplete; breaking change
- Store in SharedPreferences only — loses the data across devices; contradicts spec FR-004
- Store without adding to entity (raw Map in controller) — inconsistent with the domain model

---

## Decision 4: Router Refactor Strategy

**Decision**: Remove the `hasSeenOnboarding` check block entirely from the logged-in branch of the GoRouter redirect. Change the `!isProfileComplete` redirect target from `AppRoutes.profileSetup` to `AppRoutes.onboarding`.

**Before** (current router, abbreviated):
```dart
if (isLoggedIn) {
  // BUG: local-only flag causes wrong redirect on new devices
  if (!storageService.hasSeenOnboarding) {
    if (state.matchedLocation != AppRoutes.onboarding) return AppRoutes.onboarding;
    return null;
  }
  // BUG: routes to profile-setup which duplicates onboarding data collection
  if (!isProfileComplete) {
    if (state.matchedLocation != AppRoutes.onboarding &&
        state.matchedLocation != AppRoutes.profileSetup) {
      return AppRoutes.profileSetup;
    }
    return null;
  }
  // ...redirect off auth pages to main...
}
```

**After** (fixed router):
```dart
if (isLoggedIn) {
  // hasSeenOnboarding check removed entirely
  if (!isProfileComplete) {
    if (state.matchedLocation != AppRoutes.onboarding &&
        state.matchedLocation != AppRoutes.profileSetup) {
      return AppRoutes.onboarding;  // changed target
    }
    return null;
  }
  // ...redirect off auth pages to main (unchanged)...
}
```

**Rationale**: `authProfileCompletionProvider` already performs a Firestore lookup — it's the correct source of truth. The local flag `hasSeenOnboarding` was an optimistic shortcut that breaks on new devices. Removing it adds one Firestore read on first login but eliminates incorrect redirects entirely.

**Alternatives considered**:
- Keep `hasSeenOnboarding` as a cache hint but fall back to server check — adds complexity for marginal benefit; the Firestore read is fast and already cached by Riverpod
- Sync `hasSeenOnboarding` from Firestore on login — unnecessary; `authProfileCompletionProvider` already does this
- Route incomplete-profile users to `profileSetup` instead of `onboarding` — contradicts spec; `profileSetup` would still duplicate the onboarding UX

---

## Decision 5: SplashPage "Get Started" Navigation Target

**Decision**: Change `context.go(AppRoutes.onboarding)` to `context.go(AppRoutes.signUp)` in `SplashPage`.

**Rationale**: The spec (FR-001, FR-007) requires new users to reach account creation before onboarding profile steps. The router will automatically redirect a new authenticated user with no profile to `/onboarding` after signup completes.

**No change needed to "Already have an account"** — it already routes to `/login`.

---

## Decision 6: OnboardingPage — Saving Profile Data

**Decision**: Replace the `_finishOnboarding` method body:

**Before**:
```dart
void _finishOnboarding() {
  HapticFeedback.heavyImpact();
  ref.read(storageServiceProvider).setHasSeenOnboarding(true);
  context.go(AppRoutes.signUp);
}
```

**After**:
```dart
Future<void> _finishOnboarding() async {
  HapticFeedback.heavyImpact();
  final uid = ref.read(authSessionProvider).valueOrNull?.id;
  if (uid == null) return;                   // guard: should never happen post-signup

  await ref.read(authControllerProvider).createUserProfile(
    displayName: _nameController.text.trim(),
    workoutPreference: _goalToWorkoutType(_selectedGoalIndex),
    beginnerFlag: false,
    avatarConfig: _avatarColors[_selectedColorIndex].value
        .toRadixString(16)
        .padLeft(8, '0'),
    trainingDaysPerWeek: _selectedDays,
  );
  // Router detects isProfileComplete=true and navigates to main automatically.
  // No explicit navigation needed here.
}
```

**Rationale**: Since the user is already authenticated when onboarding runs (post-signup), calling `createUserProfile` persists directly to Firestore. The `authProfileCompletionProvider` will re-evaluate and the router redirect will handle navigation to main. No local storage flag needed.

**`setHasSeenOnboarding` note**: The flag is no longer used for routing decisions (Decision 4), so calling it is unnecessary. It is NOT removed from `StorageService` itself (other code may depend on it) but the call in `_finishOnboarding` is removed.

---

## Decision 7: `authControllerProvider` Parameter Extension

**Decision**: Add `trainingDaysPerWeek: int?` parameter to `AuthController.createUserProfile`, propagated down through `AuthenticationUseCase.createUserProfile`, `AuthRepository.createUserProfile`, and `AuthRemoteDataSource.createUserProfile`.

**Rationale**: Clean architecture — data flows down through domain layers. No layer should skip its neighbour.

**Alternatives considered**:
- Call `updateUserProfile` separately after `createUserProfile` — two Firestore writes; unnecessary
- Store via `updateUserProfile(userId, {'trainingDaysPerWeek': days})` in a separate step — same concern; adds complexity
