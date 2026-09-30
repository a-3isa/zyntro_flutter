# Research: Profile, Auth, Navigation & Social Fixes

**Feature**: 005-profile-auth-social-fixes  
**Date**: 2026-06-10

## R-001: Auth Persistence

**Decision**: Remove the 30-min TTL from `AuthLocalDataSource`; fix `routerProvider` to use `refreshListenable` instead of rebuilding GoRouter on every auth state change.

**Rationale**: Firebase Auth persists tokens natively on device (Keychain / EncryptedSharedPreferences). The 30-min TTL was an overly-conservative cache invalidation policy that fights Firebase's own token management. The `Provider<GoRouter>` pattern creates a new router on every auth state emit, causing a one-frame splash flash that may appear as sign-out.

**Alternatives considered**:
- Extend TTL to 7 days: rejected — the TTL should not govern auth session at all; Firebase token expiry is the right mechanism.
- Implement custom persistence via `FirebaseAuth.setPersistence()`: already the default on mobile; no change needed.

**Files affected**: `lib/features/auth/data/datasources/auth_local_data_source.dart`, `lib/app/navigation/app_router.dart`

---

## R-002: Back Button Navigation

**Decision**: Replace `context.go()` with `context.push()` for in-app screen transitions; add `PopScope` on `MainShell` to handle root-level back press.

**Rationale**: `GoRouter.go()` replaces the entire navigation stack, destroying back history. `GoRouter.push()` adds to the stack, allowing back navigation. The root tab shell needs explicit `PopScope(canPop: false)` because GoRouter's `ShellRoute` does not intercept Android back presses by default.

**Alternatives considered**: Custom `NavigatorObserver`: more invasive and fragile. `WillPopScope` (deprecated): replaced by `PopScope` in Flutter 3.12+.

**Files affected**: `lib/app/navigation/app_router.dart`, `lib/features/main/presentation/main_shell.dart`, and screen files using `context.go()` for non-auth navigation.

---

## R-003: Exercise Catalog Loading

**Decision**: Fix `ExerciseCatalogService.search()` to call `_fallbackSearch()` when Firestore returns 0 results (not only on exception); fix picker's `showNoResults` guard; seed Firestore from `GymExercises` local data.

**Rationale**: The fallback code path (`_fallbackSearch`) works correctly — it queries `GymExercises.search()` which is populated. The only problem is it is never reached when Firestore succeeds but returns an empty collection. The immediate fix is to activate the fallback on empty results, making the picker functional without requiring a Firestore seed. The Firestore seed is still required for long-term correctness (SC-003 in spec 004).

**Alternatives considered**: Client-side bundled JSON only (no Firestore): violates spec 004 which requires cloud catalog for shared exercise discovery.

**Files affected**: `lib/services/exercise_catalog_service.dart`, `lib/features/session/presentation/widgets/gym_exercise_picker_sheet.dart`

---

## R-004: Avatar Color Ring

**Decision**: Add `Color? ringColor` parameter to `FluttermojiAvatar`; parse from `UserProfileEntity.avatarConfig` (8-char ARGB hex) at all widget call sites where a user profile is available.

**Rationale**: The color is already stored — `avatarConfig` contains `c8ff00ff`-style ARGB hex values set during onboarding. Parsing is trivial (`Color(int.parse(avatarConfig, radix: 16))`). The widget already supports a border ring; it just needs to accept a dynamic color.

**Parsing helper** (to be added to a utility or directly in the widget):
```dart
static Color? _parseAvatarColor(String? avatarConfig) {
  if (avatarConfig == null || avatarConfig.length != 8) return null;
  final value = int.tryParse(avatarConfig, radix: 16);
  return value != null ? Color(value) : null;
}
```

**Fallback**: When `ringColor` is null, keep existing `AppColors.accentLime` ring — ensures no regression at call sites that do not yet have a profile available.

**Files affected**: `lib/widgets/fluttermoji_avatar.dart`, all call sites passing `FluttermojiAvatar(...)`.

---

## R-005: Sign-in Screen Layout

**Decision**: Remove fixed-height `SizedBox` spacers; use `Spacer` / `Flexible` + `Column(mainAxisAlignment: SpaceBetween)` pattern. Keep `SingleChildScrollView` only as a keyboard-avoidance wrapper (Flutter's `Scaffold.resizeToAvoidBottomInset: true` handles most of this automatically).

**Rationale**: `SingleChildScrollView + AlwaysScrollableScrollPhysics + fixed spacers` forces scrollability regardless of content height. A `Spacer`-based layout compresses gracefully on short screens and expands on tall ones.

**Target viewport**: 375 × 667 logical pixels (iPhone SE 2nd gen baseline). All form content must fit without scroll on this size.

**Files affected**: `lib/features/auth/presentation/login_page.dart`, `lib/features/auth/presentation/signup_page.dart`

---

## R-006: Follow Request Notification Actions

**Decision**: Extend `_buildNotificationTile` to render inline action buttons for `followRequest` type; update FCM tap handler to deep-link to requester's profile.

**Existing pieces confirmed**:
- `FollowService.acceptFollowRequest(followerId, followeeId)` ✅
- `FollowService.declineFollowRequest(followerId, followeeId)` ✅
- `FollowService.followUser(followerId, followeeId, isPrivate, followerName)` ✅
- `FollowService.getFollowStatus(followerId, followeeId)` ✅
- `AppNotification.data['fromUserId']` — requester's UID ✅
- `UserProfileEntity.isPrivate` — current user's privacy setting ✅
- FCM notification data already has `type: follow_request` and `fromUserId` ✅

**Missing**:
- Inline Follow-back / Accept / Decline buttons in the notification tile
- Check if recipient already follows requester before showing Follow-back
- After action: write `data['actionTaken']` to Firestore notification doc to persist state
- FCM tap: currently routes to `/profile/follow-requests`; needs to route to `/user/{fromUserId}`

**Files affected**: `lib/features/notifications/presentation/notifications_page.dart`, `lib/services/notification_service.dart`
