# Data Model: Fix Onboarding & Login Flow

**Date**: 2026-05-26 | **Branch**: `002-fix-onboarding-login`

## Changes Summary

One new optional field (`trainingDaysPerWeek`) added to the user profile entity and Firestore schema. No fields removed. No existing fields renamed. Fully backwards-compatible.

---

## UserProfileEntity (domain layer)

**File**: `lib/features/auth/domain/entities/user_profile_entity.dart`

### Current

```dart
class UserProfileEntity {
  final String id;
  final String displayName;
  final String? photoUrl;
  final String? avatarConfig;
  final bool isPrivate;
  final WorkoutType workoutPreference;
  final bool beginnerFlag;
}
```

### After

```dart
class UserProfileEntity {
  final String id;
  final String displayName;
  final String? photoUrl;
  final String? avatarConfig;
  final bool isPrivate;
  final WorkoutType workoutPreference;
  final bool beginnerFlag;
  final int? trainingDaysPerWeek;   // ← NEW: nullable; range 2–7
}
```

**Constraints**:
- `trainingDaysPerWeek` is nullable to preserve backwards compatibility with existing accounts that pre-date this feature
- Valid range when present: 2–7 (matching the onboarding day selector)
- Not included in the `isProfileComplete` Firestore check — existing accounts remain complete

---

## UserProfileModel (data layer)

**File**: `lib/features/auth/data/models/user_profile_model.dart`

Add `trainingDaysPerWeek: int?` field with Firestore serialisation key `"trainingDaysPerWeek"`.

```dart
// fromFirestore: 
trainingDaysPerWeek: (data['trainingDaysPerWeek'] as int?),

// toMap:
if (trainingDaysPerWeek != null)
  'trainingDaysPerWeek': trainingDaysPerWeek,
```

---

## Firestore Schema (users collection)

**Collection**: `users/{userId}`

| Field | Type | Required | Notes |
|---|---|---|---|
| `displayName` | String | Yes (completeness gate) | User's display name |
| `photoURL` | String? | No | Profile photo URL |
| `avatarConfig` | String? | No | 8-char hex ARGB string, e.g. `"ffc8ff00"` |
| `isPrivate` | Boolean | Yes | Privacy setting |
| `workoutPreference` | String | Yes (completeness gate) | WorkoutType.value, e.g. `"gym"` |
| `beginnerFlag` | Boolean | Yes | |
| `authProvider` | String | Yes | `"email"`, `"google"`, `"facebook"` |
| `trainingDaysPerWeek` | Integer? | **No** (new, optional) | Range 2–7; absent on pre-existing accounts |
| `createdAt` | Timestamp | Yes | Set on account creation |

**No migration required.** Existing documents without `trainingDaysPerWeek` are valid; the field is absent, not null.

---

## createUserProfile — Updated Signature

Propagated through all layers:

### AuthRemoteDataSource

```dart
Future<void> createUserProfile({
  required String userId,
  required String displayName,
  required WorkoutType workoutPreference,
  required bool beginnerFlag,
  String? photoUrl,
  String? avatarConfig,
  String? authProvider,
  int? trainingDaysPerWeek,        // ← NEW
})
```

Firestore write addition:
```dart
if (trainingDaysPerWeek != null)
  'trainingDaysPerWeek': trainingDaysPerWeek,
```

### AuthRepository (interface + impl)

```dart
Future<void> createUserProfile({
  ...existing params...,
  int? trainingDaysPerWeek,
});
```

### AuthenticationUseCase

```dart
Future<Result<void, AuthFailure>> createUserProfile({
  ...existing params...,
  int? trainingDaysPerWeek,
});
```

### AuthController (presentation layer)

```dart
Future<void> createUserProfile({
  ...existing params...,
  int? trainingDaysPerWeek,
});
```

---

## OnboardingSession (in-memory, no persistence)

The onboarding steps collect four values held in `_OnboardingPageState` instance variables until `_finishOnboarding` is called:

| Variable | Type | Maps to |
|---|---|---|
| `_nameController.text.trim()` | String | `displayName` |
| `_avatarColors[_selectedColorIndex]` | Color | `avatarConfig` (hex string) |
| `_selectedGoalIndex` | int | `workoutPreference` (via mapping) |
| `_selectedDays` | int | `trainingDaysPerWeek` |

**Goal index → WorkoutType mapping** (added as private helper `_goalToWorkoutType`):

```dart
WorkoutType _goalToWorkoutType(int index) {
  switch (index) {
    case 0: return WorkoutType.gym;       // Build Strength
    case 1: return WorkoutType.running;   // Improve Cardio
    case 2: return WorkoutType.hiit;      // Body Composition
    case 3: return WorkoutType.sports;    // Compete
    default: return WorkoutType.other;
  }
}
```

This state lives only for the duration of the screen; no serialisation to disk is needed.

---

## isProfileComplete — No Change

`isProfileComplete` in `AuthRemoteDataSource` continues to check only `displayName` and `workoutPreference`. `trainingDaysPerWeek` is NOT added to the completeness gate, protecting existing accounts.

```dart
// Unchanged:
return (data['displayName'] as String?)?.isNotEmpty == true &&
    data['workoutPreference'] != null;
```
