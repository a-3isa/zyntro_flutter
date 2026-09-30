# Data Model: Profile, Auth, Navigation & Social Fixes

**Feature**: 005-profile-auth-social-fixes  
**Date**: 2026-06-10

## Changed Entities

### AuthLocalDataSource

**Change**: Remove 30-minute TTL from `getCachedUser()`.

Before:
```dart
static const Duration _cacheTtl = Duration(minutes: 30);

Future<AuthUserModel?> getCachedUser() async {
  // ...
  final age = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(cachedAt),
  );
  if (age > _cacheTtl) {
    await clearCachedUser();
    return null;
  }
  // ...
}
```

After: Remove `_cacheTtl` constant and the age check entirely. The cache is now perpetual until explicitly cleared by `clearCachedUser()` (called on sign-out or Firebase auth-null event).

**Invariants preserved**:
- Cache is still cleared when Firebase emits null (sign-out path in `authStateChanges()`)
- Cache is still only a fallback — `getCurrentUser()` checks `_auth.currentUser` first

---

### FluttermojiAvatar widget

**Change**: Add `Color? ringColor` parameter.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| photoUrl | String? | No | — | Profile photo URL |
| avatarConfig | String? | No | — | avatar_plus config string |
| displayName | String | Yes | — | Used for initials fallback |
| size | double | No | 40 | Circle diameter |
| onTap | VoidCallback? | No | — | Tap handler |
| showGradientBorder | bool | No | true | Show ring border |
| **ringColor** | **Color?** | **No** | **AppColors.accentLime** | **Ring/border color** |

**Parsing at call sites**:
```dart
// Helper (add to FluttermojiAvatar or a utility):
static Color? ringColorFromConfig(String? avatarConfig) {
  if (avatarConfig == null || avatarConfig.length < 6) return null;
  final hex = avatarConfig.length == 8 ? avatarConfig : 'ff$avatarConfig';
  return Color(int.parse(hex, radix: 16));
}
```

---

### AppNotification.data (Firestore notifications collection)

**Change**: After a follow-request action is taken, write `actionTaken` to the notification's `data` map in Firestore so the button state persists across app restarts.

| Field | Type | When set | Values |
|-------|------|----------|--------|
| fromUserId | String | on creation | requester's UID |
| byUserName | String | on creation | requester's display name |
| **actionTaken** | **String?** | **after action** | `"followedBack"`, `"accepted"`, `"declined"` |

No Firestore schema migration needed — `data` is already a `Map<String, dynamic>?`.

---

### ExerciseCatalogService (search logic)

**Change**: Activate fallback when Firestore returns 0 results.

Before (simplified):
```dart
// results populated from Firestore...
// catch (e) { results = _fallbackSearch(normalized); }
return results;
```

After:
```dart
// results populated from Firestore...
if (results.isEmpty) results = _fallbackSearch(normalized);
// catch (e) { results = _fallbackSearch(normalized); }
return results;
```

This is additive and does not change Firestore read behavior.

---

### Firestore: exerciseCatalog collection (seed data)

**Seeding source**: `lib/core/data/gym_exercises.dart` → `GymExercises.all` list  
**Target collection**: `exerciseCatalog`  
**Document format** (matches `ExerciseCatalogEntry.toMap()`):

```json
{
  "name": "Bench Press",
  "normalizedName": "bench press",
  "searchTokens": ["bench", "press", "bench press"],
  "muscleGroup": "Chest",
  "equipment": "Barbell",
  "isActive": true
}
```

**Seeding mechanism**: A Dart/Flutter one-shot seed function that reads `GymExercises.all`, constructs `ExerciseCatalogEntry` objects, and batch-writes them to Firestore. Can be triggered once from a debug build or a Firebase Cloud Function. Document IDs are generated via `const Uuid().v4()`.

**Volume**: All entries in `GymExercises.all` (minimum 40+ per spec 004 FR-013).

---

## No-Change Entities

- `UserProfileEntity` — `avatarConfig` field already stores the color; no schema change needed
- `FollowService` — `acceptFollowRequest` / `declineFollowRequest` / `followUser` already exist
- `NotificationType.followRequest` — already defined and handled in the notification pipeline
- `AppNotification` — `data` map already flexible; no struct change needed
