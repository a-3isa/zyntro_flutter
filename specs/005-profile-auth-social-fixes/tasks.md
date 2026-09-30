# Tasks: Profile, Auth, Navigation & Social Fixes

**Input**: Design documents from `specs/005-profile-auth-social-fixes/`  
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with other [P] tasks in the same phase
- **[Story]**: User story this task belongs to (US1–US6)
- Exact file paths are required in every task description

---

## Phase 1: Setup (No Story Dependency)

**Purpose**: No new project initialization needed. One shared prerequisite — verifying that the auth local data source and GoRouter are correctly connected before any other changes.

- [X] T001 Read and confirm `lib/features/auth/data/datasources/auth_local_data_source.dart` full content to verify the 30-min TTL location before editing
- [X] T002 Read `lib/app/navigation/app_router.dart` full content to understand the current `routerProvider = Provider<GoRouter>` pattern before refactoring

---

## Phase 2: P1 — Stay Signed In After App Restart [US1]

**Story goal**: Users remain signed in after force-closing and reopening the app.  
**Independent test**: Sign in → force-close → reopen → verify home screen, not sign-in screen.  
**Root cause**: 30-min TTL in `AuthLocalDataSource` clears the local cache and causes `getCurrentUser()` to return null. Secondary issue: `Provider<GoRouter>` creates a new router on every auth state change causing a splash-frame flash.

- [X] T003 [US1] In `lib/features/auth/data/datasources/auth_local_data_source.dart`: remove the `_cacheTtl` constant (line ~10) and the TTL age check in `getCachedUser()`. The method should return the cached user whenever the encoded string and cachedAt timestamp are present, without any duration check. Keep `clearCachedUser()` and the `cacheUser()` methods unchanged.

- [X] T030 [US1] Document the rollback plan for T003 before merging. Add a block comment above `getCachedUser()` in `lib/features/auth/data/datasources/auth_local_data_source.dart` stating: `// TTL removed intentionally — see 005-profile-auth-social-fixes. To roll back: re-add static const Duration _cacheTtl = Duration(minutes: 30); and restore the age-check block.` Record the commit SHA of T003 in the PR description. This satisfies Constitution IV (tested rollback path MUST exist before cutover).

- [X] T031 [US1] Create `test/features/auth/auth_startup_persistence_test.dart`: write two unit tests for `AuthRepositoryImpl.getCurrentUser()`. Test 1 — mock `AuthLocalDataSource.getCachedUser()` to return a valid `AuthUserModel` with a `cachedAt` timestamp 35 minutes in the past; assert that `AuthRepositoryImpl.getCurrentUser()` returns a non-null user (validates TTL removal: before T003 this call returned null). Test 2 — mock `getCachedUser()` returning null and mock `FirebaseAuth.currentUser` returning null; assert `AuthRepositoryImpl.getCurrentUser()` returns null (sign-in required path still works). Do NOT assert on `authSessionProvider` — it uses `authStateChanges()` stream and is not affected by the local cache. Both tests MUST pass before T003 is merged. Run with `flutter test test/features/auth/auth_startup_persistence_test.dart --reporter compact`.

- [X] T004 [US1] In `lib/app/navigation/app_router.dart`: replace the `Provider<GoRouter>` pattern with a stable GoRouter instance. All changes are in this file — `app.dart` does NOT need to change. (1) At module level (bottom of file), declare `class _AuthChangeNotifier extends ChangeNotifier { void trigger() => notifyListeners(); }` and `final _authChangeNotifier = _AuthChangeNotifier();`. (2) Inside `routerProvider`, replace the three `ref.watch(...)` calls (lines 197–199) with `ref.listen(...)` calls, storing each result in a mutable closure variable: `var _authState = const AsyncValue<AuthUser?>.loading(); var _profileComplete = const AsyncValue<bool>.loading(); var _rollbackActive = const AsyncValue<bool>.data(false);`. The listeners update these vars and call `_authChangeNotifier.trigger()`. (3) Pass `refreshListenable: _authChangeNotifier` to the `GoRouter(...)` constructor. (4) The `redirect` callback reads from the closure vars (`_authState.valueOrNull`, `_authState.isLoading`, etc.) instead of `authState` — the variable names change but the logic is identical. The router is now created once and re-runs redirect via `refreshListenable` when auth state changes, eliminating the GoRouter recreation on every auth event.

- [X] T005 [US1] No change needed to `lib/app/app.dart`. The file already calls `ref.watch(routerProvider)` which returns the stable GoRouter from T004. Remove this task if it was added in a prior draft — executing it would be wrong. **Verification only**: after T004 is applied, confirm that `routerProvider` no longer contains any `ref.watch(authSessionProvider)`, `ref.watch(authProfileCompletionProvider)`, or `ref.watch(authMigrationRollbackActiveProvider)` calls (use grep: `rg "ref\.watch.*auth" lib/app/navigation/app_router.dart`).

---

## Phase 3: P2 — Hardware Back Button Navigates Within App [US2]

**Story goal**: Hardware back button navigates to previous screen; only exits app from root home screen.  
**Independent test**: Navigate 3 screens deep → press back twice → verify previous screens shown; on home screen back → verify exit prompt or normal exit (no crash).  
**Root cause**: (A) `MainShell` (root tab widget) has no `PopScope` so back at root exits immediately. (B) Some in-app navigations use `context.go()` which clears history.

- [X] T006 [US2] In `lib/features/main/presentation/main_shell.dart`: wrap the outermost `Scaffold` in the `build()` method with `PopScope(canPop: false, onPopInvokedWithResult: (didPop, result) { /* show exit dialog or double-tap-to-exit logic */ })`. Use a `DateTime? _lastBackPress` field on the state to implement a "press back again to exit" pattern: if last press was within 2 seconds, call `SystemNavigator.pop()`; otherwise show a `SnackBar` "Press back again to exit" and record the timestamp.

- [X] T007 [P] [US2] Audit `lib/features/profile/presentation/profile_page.dart` for `context.go()` calls that navigate away from a user-profile screen mid-session. Search for `context.go(AppRoutes.main)` in the file (use grep: `rg "context\.go" lib/features/profile/presentation/profile_page.dart`). Replace with `context.pop()` where returning to the previous screen is the right behavior, keeping `context.go(AppRoutes.main)` only where the entire navigation stack should be cleared (e.g., after account deletion).

- [X] T008 [P] [US2] Audit `lib/features/notifications/presentation/notifications_page.dart`: the `context.go()` calls in `_handleNotificationTap` for `buddyInvite` / `buddyAccepted` (lines ~493, 519) switch to the social tab — this is correct tab-switching behavior. No change needed for those. Confirm that notification detail navigation (e.g., `/user/:userId` and `/post/:postId` pushes) are using `context.push()` not `context.go()`, and fix any that are not.

- [X] T033 [P] [US2] Audit remaining screens for `context.go()` misuse. In `lib/features/session/presentation/recap_page.dart` and `lib/features/session/presentation/gym_session_setup_page.dart`: search for all `context.go(` calls. For each: if it navigates TO a new detail screen mid-flow (user still wants back navigation), replace with `context.push()`. Keep `context.go(AppRoutes.main)` only where the entire session flow is complete and clearing the stack is correct (e.g., post-recap return to feed). Add a one-line code comment on each replaced or kept call explaining why — e.g., `// context.push: detail screen, back navigation required` or `// context.go: session complete, clear stack`. This covers the audit gap identified in plan.md R-002 for session pages.

---

## Phase 4: P3 — Exercise Database Loads When Starting a Session [US3]

**Story goal**: Exercise picker shows a list of exercises immediately on opening; never shows a silent empty list.  
**Independent test**: Start session → tap "Add exercise" → verify exercise list appears without searching.  
**Root cause**: (A) `ExerciseCatalogService.search()` only calls `_fallbackSearch()` on exception, not on empty Firestore results. (B) `GymExercisePickerSheet.showNoResults` guard requires `query.isNotEmpty`, hiding the empty state on initial load. (C) Firestore `exerciseCatalog` collection has 0 documents.

- [X] T009 [US3] In `lib/services/exercise_catalog_service.dart`, in the `search()` method: after BOTH the `catalogSnap` loop AND the `personalSnap` loop (immediately before the `debugPrint` and `return results` on line ~330), add: `if (results.isEmpty) results = _fallbackSearch(normalized);`. This placement is critical — inserting before the personal loop would mix fallback entries with a user's personal exercises. Inserting after both loops means fallback only fires when truly nothing was found. Do not remove the `catch` block fallback — it still covers network exception cases.

- [X] T010 [US3] In `lib/features/session/presentation/widgets/gym_exercise_picker_sheet.dart`: change the `showNoResults` condition from `query.isNotEmpty && _results.isEmpty` to simply `_results.isEmpty`. Also add a separate `showInitialEmptyState` flag for when the initial `_doSearch('')` returns 0 results — this should render the same "no results" state with a prompt to try a search term or create a custom exercise. Remove `final showNoResults = ...` and replace with logic that shows the empty/no-results widget whenever `_results.isEmpty && !_loading && !_error`.

- [X] T011 [US3] Create `lib/services/exercise_catalog_seed.dart`: a standalone function `Future<void> seedExerciseCatalog(FirebaseFirestore db)` that reads `GymExercises.all`, converts each entry to `ExerciseCatalogEntry.toMap()`, and batch-writes them to the `exerciseCatalog` Firestore collection (max 500 per batch). Each document ID is generated via `const Uuid().v4()`. The function must check if the collection already has documents before seeding (use `db.collection('exerciseCatalog').limit(1).get()`) to avoid duplicates on re-run.

- [X] T012 [US3] Add a one-time seed trigger in a debug-only path. In `lib/features/settings/presentation/settings_page.dart`: add a hidden developer action (visible only when `kDebugMode == true`) that calls `seedExerciseCatalog(FirebaseFirestore.instance)` and shows a `SnackBar` on completion. This allows seeding from within a debug build without a separate script. Title the button "Seed Exercise Catalog (dev only)".

---

## Phase 5: P4 — Profile Photo Shown in Circle with Avatar Color Ring [US4]

**Story goal**: Profile circles show the user's photo (not initials) and a colored ring matching their avatar color.  
**Independent test**: Sign in as user with photo + non-lime avatar color → view profile circle → verify photo shown, ring matches avatar color.  
**Root cause**: `FluttermojiAvatar` hardcodes `AppColors.accentLime` for the ring; `profile_page.dart` has its own `_buildAvatar` that omits a colored ring entirely.

- [X] T013 [US4] In `lib/widgets/fluttermoji_avatar.dart`: add a `Color? ringColor` parameter to the `FluttermojiAvatar` constructor. In the `showGradientBorder` rendering block (line ~65): (1) replace `AppColors.accentLime` with `ringColor ?? AppColors.accentLime`, and (2) remove the `const` keyword from that outer `BoxDecoration(...)` — `const` requires all values to be compile-time constants, but `ringColor ?? AppColors.accentLime` is not a const expression, so keeping `const` will cause a compile error. The inner `BoxDecoration(shape: BoxShape.circle, color: AppColors.backgroundV2)` can stay const. Add a static helper method `static Color? colorFromAvatarConfig(String? avatarConfig)` that parses an 8-char ARGB hex string to a `Color`: `if (avatarConfig == null || avatarConfig.length != 8) return null; final v = int.tryParse(avatarConfig, radix: 16); return v != null ? Color(v) : null;`.

- [X] T014 [P] [US4] In `lib/widgets/buddies_carousel.dart`: locate the `FluttermojiAvatar(...)` call and pass `ringColor: FluttermojiAvatar.colorFromAvatarConfig(user.avatarConfig)` (or equivalent field name). If the user model here does not have `avatarConfig`, pass `ringColor: null` (keeps existing lime ring as fallback).

- [X] T015 [P] [US4] In `lib/widgets/post_card_widget.dart`: locate the `FluttermojiAvatar(...)` call and pass `ringColor: FluttermojiAvatar.colorFromAvatarConfig(post.author?.avatarConfig)`. If the author model does not carry `avatarConfig`, pass `ringColor: null`.

- [X] T016 [P] [US4] In `lib/widgets/recent_activity_card.dart`: locate the `FluttermojiAvatar(...)` call and pass `ringColor: FluttermojiAvatar.colorFromAvatarConfig(activityUser?.avatarConfig)` or `ringColor: null` if the model does not carry avatar config.

- [X] T017 [P] [US4] In `lib/widgets/session_widgets.dart` and `lib/widgets/streak_widgets.dart`: locate each `FluttermojiAvatar(...)` call and pass `ringColor: FluttermojiAvatar.colorFromAvatarConfig(user.avatarConfig)` where the user model is available, else `ringColor: null`.

- [X] T018 [US4] In `lib/features/profile/presentation/profile_page.dart`: update `_buildAvatar(User user)` to: (1) show the user's photo using `CachedNetworkImage` in a circular clip when `user.photoURL` is not null/empty (already partially done); (2) wrap the circular avatar with a `Container` that has `BoxDecoration(shape: BoxShape.circle, border: Border.all(color: avatarRingColor, width: 3))` where `avatarRingColor = FluttermojiAvatar.colorFromAvatarConfig(user.avatarConfig) ?? AppColors.accentLime`. Apply this ring to all three avatar cases: photo, avatarConfig, and initials fallback. **FR-013 reactive update**: `authUserProfileProvider` in `lib/features/auth/auth_providers.dart` is a `FutureProvider` (one-shot fetch) — the ring will NOT update when the user changes avatar color in Settings unless the provider is invalidated. After saving avatar color changes in `lib/features/settings/presentation/settings_page.dart`, call `ref.invalidate(authUserProfileProvider)` so the profile circle rebuilds with the new color across all open screens.

---

## Phase 6: P5 — Sign-in Screen Fits Mobile Viewport Without Scrolling [US5]

**Story goal**: Sign-in and sign-up screens show all fields and submit button without scroll on 375×667 viewport.  
**Independent test**: Open login screen on small emulator (375×667 px) → verify all fields and button visible without scroll, keyboard open → field stays in view.  
**Root cause**: `SingleChildScrollView + AlwaysScrollableScrollPhysics + fixed SizedBox spacers` forces scrollability regardless of screen height.

- [X] T019 [US5] In `lib/features/auth/presentation/login_page.dart`: replace the `SingleChildScrollView(physics: AlwaysScrollableScrollPhysics(), ...)` wrapping the `Column` with a layout that uses natural compression. New structure: `Scaffold(resizeToAvoidBottomInset: true, body: SafeArea(child: Padding(padding: h24, child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [topSection, formSection, bottomSection]))))`. Replace all fixed `SizedBox(height: N)` spacers between sections with `Spacer()` between logical blocks. Remove `SingleChildScrollView` entirely — `Scaffold(resizeToAvoidBottomInset: true)` handles keyboard avoidance natively across all viewport sizes. Target: all content visible on 375×667 without scroll.

- [X] T020 [P] [US5] In `lib/features/auth/presentation/signup_page.dart`: apply the same layout refactor as T019 — replace fixed spacers with `Spacer()` between logical sections (top branding, form fields, submit button, bottom link). Test on small viewport to confirm no scroll required.

---

## Phase 7: P6 — Follow Request Notification with Follow-Back and Accept Actions [US6]

**Story goal**: Follow request notifications show inline Follow-back / Accept / Decline action buttons; tapping the notification banner deep-links to the requester's profile.  
**Independent test**: Account A sends follow request → Account B opens notifications → Follow-back and Accept/Decline buttons visible → actions update notification state.

- [X] T021 [US6] In `lib/features/notifications/presentation/notifications_page.dart`: add a new private method `Widget _buildFollowRequestActions(AppNotification notification, String currentUserId)` that:
  - Reads `fromUserId = notification.data?['fromUserId'] as String?`; if null, returns `const SizedBox.shrink()`
  - Reads `actionTaken = notification.data?['actionTaken'] as String?`; if not null, shows a grey "Request handled" label and returns early
  - Calls `ref.watch(followStatusProvider(currentUserId, fromUserId))` to check if current user already follows the requester (use an existing or new provider wrapping `FollowService.getFollowStatus`)
  - Calls `ref.watch(authUserProfileProvider)` (declared in `lib/features/auth/auth_providers.dart:127`) to get `isPrivate` for the current user. **Note**: `authUserProfileProvider` is a `FutureProvider` — to get the value synchronously inside the widget, use `.when(data: (p) => p?.isPrivate ?? false, ...)`
  - Renders a `Row` of `OutlinedButton` / `FilledButton` widgets: "Follow back" (hidden if already following), "Accept" (shown only if current user is private), "Decline" (shown only if current user is private)
  - Each button calls the appropriate `FollowService` method and then calls `ref.read(notificationServiceProvider).updateNotificationData(notification.id, currentUserId, {'actionTaken': 'followedBack'|'accepted'|'declined'})` (see T022)

- [X] T022 [US6] In `lib/services/notification_service.dart`: add method `Future<void> updateNotificationData(String notificationId, String userId, Map<String, dynamic> dataUpdate)` that reads the current notification document, merges `dataUpdate` into the existing `data` map, and writes it back: `final docRef = _firestore.collection('users').doc(userId).collection('notifications').doc(notificationId); final snap = await docRef.get(); final existing = Map<String, dynamic>.from(snap.data()?['data'] as Map? ?? {}); existing.addAll(dataUpdate); await docRef.update({'data': existing});`. This persists `actionTaken` to Firestore so action buttons are hidden on next app open. Do NOT use `FieldValue.arrayUnion` (the `data` field is a Map, not an array).

- [X] T023 [US6] In `lib/features/notifications/presentation/notifications_page.dart`: update `_buildNotificationTile` to call `_buildFollowRequestActions` for `NotificationType.followRequest`. Place the actions row below the subtitle text inside the `ListTile` using a `Column` wrapping the existing subtitle + new actions row. Set the `onTap` of the tile for `followRequest` type to `context.push('/user/$fromUserId')` (deep-link to requester's profile) instead of the current `context.push('/profile/follow-requests')`.

- [X] T024 [US6] Add a `followStatusProvider` in `lib/features/notifications/presentation/notifications_page.dart` (or a new `lib/features/social/presentation/providers/follow_status_provider.dart`): `final followStatusProvider = FutureProvider.family<FollowStatus?, (String, String)>((ref, ids) async { return ref.read(followServiceProvider).getFollowStatus(ids.$1, ids.$2); });`. This allows `_buildFollowRequestActions` to reactively check follow status.

- [X] T025 [US6] In `lib/services/notification_service.dart`: update `_navigateBasedOnData()` — add a case before the `sessionId` check: `if (data['type'] == 'follow_request') { final fromUserId = data['fromUserId'] as String?; if (fromUserId != null && navigatorContext.mounted) { navigatorContext.push('/user/$fromUserId'); return; } }`. This routes FCM push notification taps for follow requests to the requester's profile page instead of the follow-requests page.

- [X] T032 [US6] Implement FR-021 (withdraw follow request → remove notification). **No existing withdraw flow — create one as part of this task.** Step 1 — in `lib/services/follow_service.dart`: add `Future<void> withdrawFollowRequest(String requesterId, String recipientId)` that (1) deletes the follow request Firestore document at `followRequests/{requesterId}_${recipientId}` (or whichever path `followUser()` writes to), and (2) queries `users/{recipientId}/notifications` for a document where `data.fromUserId == requesterId` and `type == 'followRequest'`, then updates it with `{'data.status': 'withdrawn', 'data.actionTaken': 'withdrawn'}`. Step 2 — in `lib/features/profile/presentation/profile_page.dart`: the pending-follow state is handled at `FollowStatus.pending => 'REQUESTED'`; add an `onPressed` tap handler on that button that calls `followService.withdrawFollowRequest(currentUserId, profileUserId)` and invalidates the follow status provider to refresh the button state. Step 3 — in `lib/features/notifications/presentation/notifications_page.dart`: update `_buildFollowRequestActions` to check `notification.data?['status'] == 'withdrawn'` and render a grey "Request withdrawn" chip instead of action buttons.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T029 Add production telemetry before cutover (Constitution IV: telemetry MUST be active before cutover). Step 1 — add `firebase_analytics: ^10.0.0` (or latest compatible version) to `pubspec.yaml` dependencies and run `flutter pub get`. Step 2 — in `lib/features/auth/data/datasources/auth_local_data_source.dart`: call `FirebaseAnalytics.instance.logEvent(name: 'auth_startup_cache_hit')`, `'auth_startup_cache_miss'`, or `'auth_startup_sign_in_required'` at each corresponding branch in `getCachedUser()` and `clearCachedUser()`. Step 3 — in `lib/services/exercise_catalog_service.dart`: log `'exercise_catalog_firestore_hit'` when Firestore returns ≥1 result, or `'exercise_catalog_fallback_used'` when the local fallback fires. Step 4 — in `lib/services/notification_service.dart`: log `'follow_notification_delivered'` after the FCM + Firestore write completes successfully. Do NOT wrap any of these calls in `kDebugMode` — telemetry must run in production builds.

- [X] T026 Run `flutter analyze lib/` and fix any new warnings or errors introduced by changes in T003–T025. Cap output to first 80 lines.

- [ ] T027 [P] Manually verify QS-1 through QS-6 from `specs/005-profile-auth-social-fixes/quickstart.md` on a physical or emulated Android device. Record pass/fail against each acceptance scenario in spec.md. **Critical sub-steps**: (a) QS-1 step 6 — the 30-min wait test MUST be executed (sign in, wait 30+ minutes or advance system clock, force-close, reopen → verify home shown without re-entry; this validates FR-002a silent token refresh). (b) QS-2 steps 7–9 — open any bottom sheet, press back, verify sheet dismisses and app does not exit; this validates FR-006.

- [X] T028 [P] Verify that the Firestore seed (T011/T012) has been executed and the `exerciseCatalog` collection in Firebase contains at least 40 documents. If not, trigger the debug seed action from T012 in a debug build.

---

## Dependencies

```
T001 → T003 (read before edit)
T002 → T004 (read before edit)
T003 and T004 are independent fixes (different files) — run them in parallel after T001/T002 respectively
T004 → T005 (T005 is a verification grep; run after T004 is applied)
T003 → T030 → T031 (rollback doc and regression test follow TTL removal)
T006 (standalone)
T007, T008, T033 (parallel, independent — all nav audits)
T009 → T010 → T011 → T012 (sequential within P3)
T013 → T014, T015, T016, T017, T018 (T013 must complete first; T014–T018 parallel after)
T019, T020 (parallel, independent)
T021 → T023, T024 (T021 defines the actions widget; T023/T024 integrate it)
T022 (parallel with T021 — different method, different file section)
T025, T032 (parallel — both in notification/follow service, different methods)
T012 and T018 both touch settings_page.dart — execute sequentially, not in parallel
T029 (standalone — add after all other implementation tasks, before T026)
T030 → T031 (rollback doc before regression test)
T026–T028 (after all implementation tasks)
```

## Parallel Execution Opportunities

**Group A (run together after T005)**:
- T006 (PopScope on MainShell)
- T007 (profile_page.dart nav audit)
- T008 (notifications_page.dart nav audit)
- T033 (recap + session_setup nav audit)

**Group B (run together after T013)**:
- T014 (buddies_carousel.dart)
- T015 (post_card_widget.dart)
- T016 (recent_activity_card.dart)
- T017 (session_widgets.dart + streak_widgets.dart)

**Group C (run together)**:
- T019 (login_page.dart)
- T020 (signup_page.dart)

**Group D (run together after T021/T022)**:
- T023 (integrate actions into tile + update tap handler)
- T024 (add followStatusProvider)
- T025 (FCM tap routing update)
- T032 (FR-021 withdraw follow request notification)

## Implementation Strategy — Suggested Order

**MVP (ship-first)**: T003 + T030 + T031 + T004 + T005 → fixes the #1 user complaint with rollback doc and regression test.

**High impact, low risk**: T006 (PopScope) + T009 + T010 → back button fix and exercise DB fix.

**Visual polish**: T013 → T014–T018 in parallel → profile circle updates (+ `ref.invalidate` in settings from T018).

**Layout fix**: T019 + T020 in parallel.

**Social feature**: T021 → T022 → T023 + T024 + T025 + T032 → T011 + T012 (seed).

**Constitution compliance**: T029 (telemetry) added before T026 in Phase 8 — run last before polish.

**Total tasks**: 33  
**Tasks per story**: US1: 5 (added T030, T031), US2: 4 (added T033), US3: 4, US4: 6, US5: 2, US6: 6 (added T032)  
**Parallel groups**: 4 identified  
**Setup/polish tasks**: 5 (T001, T002, T026, T027, T028)
