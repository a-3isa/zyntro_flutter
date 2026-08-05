# Implementation Plan: Profile, Auth, Navigation & Social Fixes

**Branch**: `005-profile-auth-social-fixes` | **Date**: 2026-06-10 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `specs/005-profile-auth-social-fixes/spec.md`

## Summary

Six concrete fixes and features, ordered by user impact:
1. **Auth persistence** — remove 30-min local cache TTL blocking silent re-auth; fix GoRouter rebuild pattern.
2. **Back button navigation** — replace `context.go()` deep-navigation calls with `context.push()`; add PopScope on root tab shell.
3. **Exercise catalog loading** — fix `ExerciseCatalogService` to fall back to local data when Firestore returns 0 docs (not just on error); fix picker's empty-query empty-state; seed Firestore from local `GymExercises` data.
4. **Profile photo + avatar color ring** — extend `FluttermojiAvatar` to accept an optional `Color? ringColor`; derive color from `UserProfileEntity.avatarConfig` (stored as ARGB hex) at all call sites.
5. **Sign-in / sign-up screen responsiveness** — replace `SingleChildScrollView + Column` with a `LayoutBuilder`-driven layout using proportional spacing so all content fits without scroll on 375×667 minimum viewports.
6. **Follow request notification actions** — extend `_buildNotificationTile` in `NotificationsPage` to render Follow-back, Accept, and Decline inline action buttons for `followRequest` type; configure FCM notification tap to deep-link to requester's profile.

## Technical Context

**Language/Version**: Dart 3 / Flutter 3.x  
**Primary Dependencies**: Firebase Auth, Cloud Firestore, Firebase Messaging (FCM), flutter_riverpod, go_router, flutter_local_notifications, avatar_plus  
**Storage**: Cloud Firestore (primary), SharedPreferences (local auth cache only)  
**Testing**: `flutter test` (unit), widget tests  
**Target Platform**: Android (primary), iOS  
**Performance Goals**: Picker initial load ≤ 2 s; push notification delivery ≤ 5 s; follow action round-trip ≤ 2 s  
**Constraints**: Zero scroll on 375×667 viewport for auth screens; 100% back-button intercept on non-root screens  
**Scale/Scope**: Single mobile app; exercise catalog minimum 40 entries seeded from existing `GymExercises` local data

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Feature-Slice Scope Discipline | ✅ PASS | All 6 items are in-scope; exercise seeding cross-references spec 004 explicitly |
| II. Evidence-First Cutover | ✅ PASS | Each story has independent acceptance scenarios; regression evidence required before cutover |
| III. Security and Access Integrity | ✅ PASS | Auth persistence fix preserves Firebase token validation; no auth bypass |
| IV. Operational Safety and Reversibility | ✅ PASS | Auth cache change is additive; Firestore seeding is append-only; GoRouter change is reversible |
| V. Independent Deliverability | ✅ PASS | All 6 stories are independently implementable; P1/P2 have no story cross-dependencies |

**Post-design re-check**: Required after Phase 1; auth session changes must be regression-verified before cutover.

## Project Structure

### Documentation (this feature)

```text
specs/005-profile-auth-social-fixes/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── datasources/
│   │   │       └── auth_local_data_source.dart   ← P1: remove 30-min TTL
│   │   └── presentation/
│   │       ├── login_page.dart                   ← P5: layout refactor
│   │       └── signup_page.dart                  ← P5: layout refactor
│   ├── notifications/
│   │   └── presentation/
│   │       └── notifications_page.dart            ← P6: follow action buttons
│   └── session/
│       └── presentation/
│           └── widgets/
│               └── gym_exercise_picker_sheet.dart ← P3: empty-state fix
├── services/
│   ├── exercise_catalog_service.dart              ← P3: fallback-on-empty fix
│   ├── follow_service.dart                        ← P6: read (already has accept/decline)
│   └── notification_service.dart                 ← P6: FCM tap deep-link
├── widgets/
│   └── fluttermoji_avatar.dart                    ← P4: ringColor parameter
└── app/
    └── navigation/
        └── app_router.dart                        ← P2: back-button / router fix
```

---

## Phase 0: Research

### R-001: Auth Persistence Root Cause

**Decision**: Two independent root causes found.

**Root Cause A — Local cache TTL (30 min)**:  
`lib/features/auth/data/datasources/auth_local_data_source.dart:10`:
```dart
static const Duration _cacheTtl = Duration(minutes: 30);
```
`getCachedUser()` returns `null` after 30 minutes and calls `clearCachedUser()`. This cache is used as a fallback in `AuthRepositoryImpl.getCurrentUser()`. Although `authSessionProvider` uses Firebase's `authStateChanges()` stream (not `getCurrentUser()`), any caller of `getCurrentUser()` (e.g., background checks) will see a null user after 30 min.

**Root Cause B — GoRouter rebuilds on auth state change**:  
`lib/app/navigation/app_router.dart:196`: `routerProvider = Provider<GoRouter>`. Every time `authSessionProvider` emits (including the first real value after loading), a **new** `GoRouter` is created with `initialLocation: AppRoutes.splash`. The `MaterialApp.router` receives the new router. Although the `redirect` function should immediately redirect logged-in users to main, there is a 1-frame window where the app shows splash. On slower devices, this can appear as being "signed out."

**Fix strategy**:
- Remove the 30-min TTL check entirely from `getCachedUser()`. Firebase Auth already handles token refresh natively; the local cache should act purely as a startup-latency shortcut, not as a TTL-gated session.
- Convert `routerProvider` from `Provider<GoRouter>` to a single GoRouter instance that uses `refreshListenable` to re-evaluate the `redirect` function when `authSessionProvider` changes, without recreating the router.

**Alternatives considered**: Extending TTL to 7 days — rejected because the real fix is to not use the TTL for auth session decisions at all.

---

### R-002: Back Button Root Cause

**Decision**: `context.go()` is used for in-app navigation (non-auth redirects) in several places, replacing the entire navigation stack rather than pushing. GoRouter's `go()` removes all prior routes from the stack, so the hardware back button has nothing to pop.

**Affected files** (partial):
- `lib/features/notifications/presentation/notifications_page.dart` — `context.go()` for tab navigation
- `lib/features/main/presentation/main_shell.dart` — tab switching via `go()`
- Various pages using `context.go(AppRoutes.main)` after completing actions

**Fix strategy**:
- Standardize: use `context.push()` for navigating TO a new screen from within an authenticated context. Use `context.go()` only for auth redirects (login → main, signup → main) and tab-bar switching.
- Add `PopScope(canPop: false, onPopInvokedWithResult: ...)` on `MainShell` (the root tab widget) to handle back-press at the root level — either show a confirmation dialog or exit the app.
- `ShellRoute` in go_router does not handle the Android back button by default; explicit `PopScope` on the shell is required.

**Alternatives considered**: Using a custom `NavigatorObserver` — rejected as more complex than needed for this scope.

---

### R-003: Exercise Catalog Empty State Root Cause

**Decision**: Two bugs plus a missing seed.

**Bug A — Fallback never fires on empty Firestore**:  
`lib/services/exercise_catalog_service.dart`: The `_fallbackSearch()` is only called in the `catch` block. When Firestore is not seeded, `catalogSnap.docs` is empty; no exception is thrown; an empty `results` list is returned with no fallback.

**Bug B — Picker silently shows blank with empty query**:  
`lib/features/session/presentation/widgets/gym_exercise_picker_sheet.dart:182`:
```dart
final showNoResults = !_loading && !_error && query.isNotEmpty && _results.isEmpty;
```
`query.isNotEmpty` prevents the no-results state from showing on the initial load (empty query). When Firestore has no docs, the picker renders an empty column with no message.

**Missing seed**: Firestore collection `exerciseCatalog` contains 0 documents. The local fallback data in `lib/core/data/gym_exercises.dart` (`GymExercises`) is complete and ready.

**Fix strategy**:
- In `ExerciseCatalogService.search()`: after fetching Firestore, if `results.isEmpty`, call `_fallbackSearch(normalized)` regardless of whether an exception occurred. This ensures local data is shown whenever Firestore returns nothing.
- In `GymExercisePickerSheet`: remove the `query.isNotEmpty` guard from `showNoResults`, OR better: show a populated list from the initial `_doSearch('')` response.
- Seed Firestore: write a one-time seed script that writes all `GymExercises` entries to the `exerciseCatalog` Firestore collection using the `ExerciseCatalogEntry.toMap()` format.

---

### R-004: Avatar Color Storage

**Decision**: Avatar color is stored in `UserProfileEntity.avatarConfig` as an 8-character lowercase hex ARGB string (e.g., `"c8ff00ff"` = lime green, `"38bdf8ff"` = sky blue).

**Parsing**: `Color(int.parse(avatarConfig, radix: 16))` or:
```dart
Color? ringColorFromAvatarConfig(String? avatarConfig) {
  if (avatarConfig == null || avatarConfig.length != 8) return null;
  final value = int.tryParse(avatarConfig, radix: 16);
  return value != null ? Color(value) : null;
}
```

**`FluttermojiAvatar` current behavior**: `showGradientBorder: true` renders a hardcoded `AppColors.accentLime` ring. No avatar color is passed.

**Fix strategy**: Add `Color? ringColor` parameter to `FluttermojiAvatar`. When provided, use it as the ring color. When null, fall back to `AppColors.accentLime`. Update all call sites that have the current user's profile available to pass the parsed ring color.

---

### R-005: Sign-in Screen Layout

**Decision**: The `SingleChildScrollView` + fixed spacers in `login_page.dart` overflow on small screens (~375×667 px) because the fixed `SizedBox` spacers do not collapse.

**Fix strategy**: Replace the `Column` + fixed spacers with:
```
Scaffold → SafeArea → Column (mainAxisAlignment: spaceBetween) {
  top section: back button + heading
  middle section: form fields + buttons
  bottom section: social login + account link
}
```
Use `Flexible` / `Spacer` for spacing so the layout compresses naturally on short screens. Wrap in a `LayoutBuilder` only if dynamic font scaling is needed. Keep `SingleChildScrollView` ONLY for keyboard-avoidance (or use `resizeToAvoidBottomInset: true` on the Scaffold, which Flutter handles natively).

Same pattern applies to `signup_page.dart`.

---

### R-006: Follow Request Notification Actions

**Decision**: All required backend pieces exist:
- `NotificationService.notifyFollowRequest()` — already sends FCM push + Firestore notification entry
- `FollowService.acceptFollowRequest()` / `declineFollowRequest()` — exist and work
- `NotificationType.followRequest` — handled in `_handleNotificationTap()` but only navigates to `/profile/follow-requests`
- `AppNotification.data` — contains `fromUserId` and `byUserName` for the requester

**Missing**:
1. Inline action buttons in `_buildNotificationTile` for `followRequest` type
2. Real-time check: is current user already following requester? (to show/hide Follow-back)
3. Real-time check: is current user's account private? (to show Accept/Decline)
4. FCM notification tap deep-link to requester's profile (currently goes to `/profile/follow-requests`)

**Fix strategy**:
- Extract `_buildFollowRequestActions` widget that reads `fromUserId` from `notification.data`, checks follow status and privacy setting, and renders the appropriate buttons.
- Update `_handleNotificationTap` for `followRequest` to push to `/user/{fromUserId}` (requester's profile) when the notification body is tapped (not an action button).
- Update FCM notification tap handler in `NotificationService` to route to `/user/{fromUserId}` instead of `/profile/follow-requests` when data type is `follow_request`.
- Mark notification as accepted/declined in Firestore after action, not just in the local UI.

---

## Phase 1: Design & Contracts

### Data Model

See [data-model.md](data-model.md) for entity details. Key changes:

**`AuthLocalDataSource`** — Remove TTL:
```dart
// REMOVE:
static const Duration _cacheTtl = Duration(minutes: 30);
// REMOVE TTL check in getCachedUser()
```

**`FluttermojiAvatar` widget parameter addition**:
```
ringColor: Color?   // new optional param; falls back to AppColors.accentLime
```

**`ExerciseCatalogService.search()` logic change**:
```
after Firestore fetch:
  if results.isEmpty → results = _fallbackSearch(normalized)
```

**Follow request notification tile new state**:  
`AppNotification.data` already carries `fromUserId`; no schema change needed. The action state (accepted/declined/pending) can be reflected by the existing `notification.read` flag plus a new `data['actionTaken']` field written after action.

**Firestore seeding format** (existing `ExerciseCatalogEntry.toMap()`):
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

### Interface Contracts

**GoRouter refresh pattern**:
```dart
// Replace Provider<GoRouter> with:
final _authStateListenable = _AuthStateListenable();
final router = GoRouter(
  initialLocation: AppRoutes.splash,
  refreshListenable: _authStateListenable,
  redirect: (context, state) { ... },
  routes: [...],
);

class _AuthStateListenable extends ChangeNotifier {
  void notify() => notifyListeners();
}
```
Wire `authSessionProvider` changes to call `_authStateListenable.notify()` via a ProviderObserver or a dedicated watcher widget at app startup.

**FCM notification data contract** (no change needed — already uses `fromUserId`):
```json
{ "type": "follow_request", "fromUserId": "uid123", "byUserName": "Alex" }
```
Tap handler update: route to `/user/{fromUserId}` when type is `follow_request`.

### Quickstart

See [quickstart.md](quickstart.md) for manual test steps. Key verification paths:

1. Sign in → force-close app → reopen → verify home screen without sign-in prompt.
2. Navigate 2+ screens deep → press hardware back → verify previous screen shown.
3. Open exercise picker → verify exercises list shown without searching.
4. Open profile → verify photo in circle + colored ring matching onboarding color.
5. Open login screen on small device → verify no scroll required.
6. Send follow request from account A to account B → open notifications on B → verify Follow-back / Accept / Decline buttons.

---

## Phases Summary

| Phase | Output | Status |
|-------|--------|--------|
| Phase 0 | research.md | ✅ Complete |
| Phase 1 | data-model.md, quickstart.md, contracts | ✅ Complete (inline above) |
| Phase 2 | tasks.md | ⏳ Next: `/speckit-tasks` |

## Complexity Tracking

No constitution violations found. No entries needed.
