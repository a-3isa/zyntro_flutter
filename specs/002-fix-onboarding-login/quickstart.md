# Developer Quickstart: Fix Onboarding & Login Flow

**Branch**: `002-fix-onboarding-login` | **Date**: 2026-05-26

## What This Feature Does

Reorders the auth entry flow: users create an account first, then complete their profile (name, avatar, goal, training days) in a post-signup onboarding step. Fixes a routing bug where returning users on new devices were incorrectly redirected to onboarding.

## Correct Flow After This Change

```
New user:      Splash → Signup → Onboarding (post-auth) → Main
Returning:     Splash → Login → Main
Incomplete:    Splash → Login → Onboarding (recovery) → Main
```

## Files to Change

| File | Change |
|---|---|
| `lib/app/navigation/app_router.dart` | Remove `hasSeenOnboarding` block; change `!isProfileComplete` target to `/onboarding` |
| `lib/features/auth/presentation/splash_page.dart` | "Get Started" → `context.go(AppRoutes.signUp)` |
| `lib/features/auth/presentation/onboarding_page.dart` | `_finishOnboarding` calls `createUserProfile`; no explicit navigation |
| `lib/features/auth/domain/entities/user_profile_entity.dart` | Add `trainingDaysPerWeek: int?` |
| `lib/features/auth/data/models/user_profile_model.dart` | Add `trainingDaysPerWeek` serialisation |
| `lib/features/auth/domain/repositories/auth_repository.dart` | Add `trainingDaysPerWeek` param |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | Pass through `trainingDaysPerWeek` |
| `lib/features/auth/data/datasources/auth_remote_data_source.dart` | Write `trainingDaysPerWeek` to Firestore |
| `lib/features/auth/domain/usecases/authentication_usecase.dart` | Add `trainingDaysPerWeek` param |
| `lib/features/auth/presentation/providers/auth_controller.dart` | Add `trainingDaysPerWeek` param |

## Key Router Change

Remove this block from `app_router.dart` (inside the `isLoggedIn` branch):
```dart
// REMOVE THIS BLOCK:
if (!storageService.hasSeenOnboarding) {
  if (state.matchedLocation != AppRoutes.onboarding) {
    return AppRoutes.onboarding;
  }
  return null;
}
```

And change the incomplete-profile redirect target:
```dart
// BEFORE:
return AppRoutes.profileSetup;
// AFTER:
return AppRoutes.onboarding;
```

## Key OnboardingPage Change

In `_finishOnboarding`, replace the current body with a `createUserProfile` call using the collected state:
- `displayName` ← `_nameController.text.trim()`
- `workoutPreference` ← `_goalToWorkoutType(_selectedGoalIndex)` (see data-model.md for mapping)
- `avatarConfig` ← `_avatarColors[_selectedColorIndex].value.toRadixString(16).padLeft(8, '0')`
- `trainingDaysPerWeek` ← `_selectedDays`

Do not call `storageService.setHasSeenOnboarding` or `context.go(...)` — the router handles navigation after `authProfileCompletionProvider` updates.

## Testing Manually

1. **New user path**: Delete the app / use a fresh Firebase account. Launch → "Get Started" → should land on signup, not onboarding → create account → onboarding steps appear → complete → lands on main with profile populated
2. **Returning user path**: Log in with an existing account that has a complete profile → should land directly on main, no onboarding redirect
3. **New device simulation**: Log out, clear SharedPreferences (`flutter clean` or wipe app data), log in again → should land on main (not onboarding) for a profile-complete account
4. **Incomplete profile recovery**: Create account but quit before completing onboarding → relaunch → login → onboarding should appear to complete the profile

## Running Tests

```powershell
flutter test test/app/navigation/ --reporter compact
flutter test test/features/auth/ --reporter compact
```
