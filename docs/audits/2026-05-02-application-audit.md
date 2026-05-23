# Zyntro Application Audit

Date: 2026-05-02
Scope: local-only audit of Flutter frontend, mobile platform integration, Firebase backend/security, architecture, data integrity, testing, CI/CD, and release readiness.

## Executive Summary

Zyntro is not currently release-ready. The largest risks are Firebase authorization gaps, client-granted paid/moderator privileges, broken native flavor builds, tracked/bundled environment files, failing analyzer/tests, and incomplete mobile release configuration.

The app has a good base of contract tests and a clear clean-architecture migration direction, but many protections are source-contract checks rather than emulator-backed authorization tests. Auth has the strongest layering; most other features still depend directly on root services or Firebase from presentation code.

## Verification Evidence

| Command | Result | Notes |
| --- | --- | --- |
| `flutter --version` | Pass | Local toolchain is Flutter 3.38.9 / Dart 3.10.8. |
| `dart --version` | Pass | Local Dart is 3.10.8. |
| `flutter pub get` | Pass with warnings | 102 packages have newer incompatible versions; `record_linux` override is active. |
| `flutter analyze` | Fail | `AuthUserEntity` is not resolved in `test/features/session/presentation/session_invite_acceptance_page_test.dart:88`. |
| `flutter test` | Blocked | Timed out after 304 seconds. |
| `flutter test test/firebase/firestore_rules_contract_test.dart` | Pass | 5 tests passed. Coverage is source-contract level, not emulator-backed rule enforcement. |
| `flutter test test/services/push_delivery_backend_contract_test.dart` | Pass | 1 test passed. |
| `flutter test test/services/notification_delivery_boundary_test.dart` | Pass | 1 test passed. |
| `flutter test test/features/session/presentation/start_session_page_test.dart` | Fail | 4 failures from stale text expectations / missing widgets. |
| `flutter test test/app/navigation/app_route_locations_test.dart` | Pass | 2 tests passed. |
| `flutter test test/core/theme/app_theme_palette_contract_test.dart` | Fail | Palette expects neon green `0xFF39FF14`; implementation uses `0xFF4ADE80`. |
| `flutter test test/features/main/presentation/main_shell_theme_test.dart` | Pass | 1 test passed. |
| `flutter build apk --flavor dev --dart-define=ENV=dev --debug` | Fail | Android Gradle project has no product flavors; `assembleDevDebug` missing. |
| `flutter build apk --flavor prod --dart-define=ENV=prod --release` | Fail | Android Gradle project has no product flavors; `assembleProdRelease` missing. |
| `flutter build apk --debug` | Blocked | Timed out after 244 seconds. |
| `.\gradlew.bat :app:assembleDebug --warning-mode all` | Fail | Early Gradle failure with terse `25.0.1` error under direct Java invocation. |
| `npm audit --json` in `functions` | Fail | 13 vulnerabilities: 1 critical, 2 low, 10 moderate. Critical is transitive `protobufjs`. |
| `npm ls --depth=0` in `functions` | Pass | Direct deps: `firebase-admin@12.7.0`, `firebase-functions@6.6.0`. |
| `flutter pub outdated` | Partial with warnings | 48 locked packages older than upgradable, 41 constraints older than resolvable, discontinued `js`; advisory decode warnings from pub.dev. |
| `scripts/validate_feature_layers.ps1` | Fail | Non-auth features missing expected domain/data layers. |

## Findings

### Critical

1. Users can self-assign moderator state at profile creation.

Evidence: `firebase/firestore.rules` allows owner create on `/users/{userId}` without field restrictions, while `isModerator()` trusts `users/{uid}.isModerator`. The update path blocks moderation field changes after the document exists, but create does not.

Impact: a malicious new user can create their own profile with `isModerator: true`, then use moderator-only powers.

Recommended fix: restrict user create/update schemas, deny moderation fields on client create, and move moderator assignment to server/admin custom claims or trusted backend writes.

Verification: emulator test where an authenticated new UID attempts to create `users/{uid}` with `isModerator: true`; it must deny.

2. Paid/global leaderboard entitlement is client-grantable.

Evidence: owner profile updates allow all non-moderation fields, while `lib/services/payment_service.dart` and `lib/services/leaderboard_service.dart` grant `hasGlobalLeaderboardAccess` from client code. Payment intent creation is mocked client-side.

Impact: users can grant paid access and fake payment/transaction fields without a verified Stripe payment.

Recommended fix: deny client writes to entitlement/payment/audit fields. Create PaymentIntents and grant access only from authenticated backend/webhook code.

Verification: emulator tests deny owner writes to `hasGlobalLeaderboardAccess` and transaction fields.

3. CI builds native flavors that do not exist.

Evidence: GitHub Actions and Codemagic call `--flavor dev` / `--flavor prod`, but `android/app/build.gradle.kts` defines no `productFlavors`; local flavor builds fail with missing `assembleDevDebug` and `assembleProdRelease`.

Impact: release/dev build jobs cannot produce APK/AAB from a clean native project.

Recommended fix: add Android `dev/staging/prod` product flavors and matching iOS schemes/configurations, or remove `--flavor` from all build commands.

Verification: `flutter build apk --flavor prod --dart-define=ENV=prod --release` succeeds.

4. CI Flutter version is incompatible with the Dart SDK constraint.

Evidence: `pubspec.yaml` requires Dart `^3.10.4`; GitHub Actions and Codemagic pin Flutter `3.24.0`, which ships an older Dart SDK. Local toolchain is Flutter 3.38.9 / Dart 3.10.8.

Impact: CI dependency resolution is expected to fail before analysis/tests/builds.

Recommended fix: pin CI to Flutter 3.38.x or another Flutter release with Dart 3.10.4+, or lower the SDK constraint intentionally.

Verification: CI `flutter --version` and `flutter pub get` succeed.

5. Environment files are committed and bundled as app assets.

Evidence: `git ls-files` confirms `.env`, `.env.dev`, `.env.staging`, and `.env.prod` are tracked. `pubspec.yaml` bundles all four as Flutter assets.

Impact: any values in those files are recoverable from source history and shipped app bundles.

Recommended fix: remove secret-bearing env files from Git, rotate exposed credentials, stop bundling `.env*`, and inject public config through CI / `--dart-define`.

Verification: release APK/AAB `flutter_assets` contains no `.env*`; secret scan is clean.

### High

6. Session membership and session state can be forged.

Evidence: session update rules allow either a current participant or anyone whose UID appears in the resulting `participants` array. Existing participants can update broad lifecycle/state fields.

Impact: users can self-join known sessions, alter lifecycle state, active user, summaries, invite lists, or participant metadata.

Recommended fix: split rules by operation. Host/server controls lifecycle fields; invited user acceptance requires `request.auth.uid in resource.data.invitedUserIds`; participants may only write narrow presence/event/own plan fields.

Verification: emulator tests for uninvited self-join, participant changing `status`, participant changing `activeUserId`, and invited acceptance.

7. Private follow requests can be self-approved by the follower.

Evidence: follow create checks only `followerId == request.auth.uid`; follow update allows either follower or followee.

Impact: a follower can create or update their own follow document to `approved`, bypassing private-account approval.

Recommended fix: require private-account follows to start pending, and allow only the followee to transition pending to approved.

Verification: emulator test where follower updates a pending request to approved; it must deny.

8. In-app notifications are spoofable.

Evidence: `/users/{userId}/notifications` allows any authenticated user to create if the document `userId` matches the path. Client creation accepts arbitrary title/message/data.

Impact: any authenticated user can create fake notifications for another user.

Recommended fix: make cross-user notifications server-owned, or restrict client creates to self-owned notification documents with a narrow schema.

Verification: emulator test as user A creating `/users/B/notifications/*`; it must deny.

9. Firebase Storage rules are missing from repo/deploy config.

Evidence: `firebase.json` configures functions and Firestore but not Storage. No `storage.rules` file was found. Client code uploads profile photos, post media, voice notes, and arbitrary paths.

Impact: production media behavior depends on console/default/stale rules. Uploads may fail or be over-permissive.

Recommended fix: add `storage.rules` and wire it into `firebase.json`; enforce auth, path ownership, session membership, content type, size, and immutable media binding.

Verification: Storage emulator tests for unauthorized upload/read, wrong user path, non-session voice note upload, oversized file, bad content type, and arbitrary path upload.

10. Firebase native config is ignored/untracked while CI only writes `.env`.

Evidence: `.gitignore` ignores `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`; CI writes only `.env`; `main.dart` calls `Firebase.initializeApp()` without generated Dart options.

Impact: clean CI/mobile clones may fail Firebase initialization or Android Google Services processing unless native config is injected elsewhere.

Recommended fix: inject native Firebase files per flavor during CI or initialize with generated `DefaultFirebaseOptions.currentPlatform`.

Verification: clean clone without local native config can build and launch Firebase initialization.

11. iOS microphone privacy declaration is missing for voice recording.

Evidence: voice recording code requests microphone access, but `ios/Runner/Info.plist` only declares camera/photo usage.

Impact: iOS can reject or crash microphone access, and App Store review can flag missing privacy copy.

Recommended fix: add `NSMicrophoneUsageDescription`; verify Android merged manifest includes `RECORD_AUDIO`.

Verification: fresh install on iOS device can start a voice note from permission prompt state.

12. Stripe payment flow is not production-ready.

Evidence: Stripe publishable key is loaded in `main.dart`, but PaymentIntent creation returns mock client secrets and entitlement granting happens in client services.

Impact: real purchases cannot be safely completed, and mock/forged payment paths can grant access.

Recommended fix: move PaymentIntent creation and entitlement granting to backend functions/webhooks; fail fast if production Stripe config is incomplete.

Verification: Stripe test-mode end-to-end payment grants entitlement only after confirmed webhook.

13. FCM token lifecycle is incomplete.

Evidence: token is saved during auth, but no `onTokenRefresh` or `getInitialMessage` handling was found.

Impact: rotated tokens may go stale and terminated-state notification taps can be lost.

Recommended fix: subscribe to `FirebaseMessaging.instance.onTokenRefresh`, persist refreshed tokens, and handle `getInitialMessage()` during startup.

Verification: token rotation and notification taps work in foreground, background, and terminated states.

14. Auth redirects drop protected deep links.

Evidence: unauthenticated protected routes redirect to login, and login success routes to main.

Impact: users opening session invites, rooms, notifications, or profile links while signed out lose the original destination.

Recommended fix: preserve the protected URI as `from`, then route back after login/profile completion.

Verification: widget test: unauthenticated `/session/accept/session-1` -> login -> authenticated -> accept page.

15. Session room and resume flows can use the wrong workout mode.

Evidence: session room defaults missing `type` to `strength`; active-session resume hardcodes `?type=gym`.

Impact: direct links or resumed non-gym sessions can show the wrong UI mode.

Recommended fix: derive room mode from session data and participant type, using query `type` only as a hint.

Verification: provider/widget tests for non-gym active session resume and route without query type.

16. Current analyzer and test suite fail.

Evidence: `flutter analyze` fails on unresolved `AuthUserEntity`; targeted tests fail for start-session text expectations and theme palette contract.

Impact: branch is not merge/release ready.

Recommended fix: fix the compile error first, then reconcile intended UI/test contracts for session start and theme palette.

Verification: `flutter analyze && flutter test` passes.

17. Clean architecture migration is incomplete outside auth.

Evidence: layer validation passes auth but fails feed, main, moderation, notifications, profile, session, settings, and social. Presentation code still imports root services and Firebase directly.

Impact: documented architecture boundaries are not broadly implemented or enforced.

Recommended fix: treat auth as the completed slice and migrate feature-by-feature. Add CI layer validation and import-boundary rules.

Verification: `scripts/validate_feature_layers.ps1` passes and CI enforces it.

18. Codemagic can publish despite failed analyze/tests.

Evidence: production Android/iOS Codemagic workflows mark analyze and tests with `ignore_failure: true`.

Impact: broken builds can reach internal Google Play/TestFlight pipelines.

Recommended fix: remove `ignore_failure` from quality gates.

Verification: intentionally failing test blocks Codemagic publish.

### Medium

19. Post privacy is UI-only, not rule-enforced.

Evidence: Firestore rules allow all authenticated users to read all posts, while UI/services model post visibility and private-account expectations.

Impact: private/followers/friends posts are readable by direct Firestore queries.

Recommended fix: enforce visibility in rules using author, approved follow/buddy relationship, or denormalized ACL arrays.

Verification: emulator tests for unaffiliated authenticated users reading private/followers/friends posts.

20. Cloud Function lacks App Check enforcement and uses wildcard CORS.

Evidence: the app activates App Check, but `deliverNotificationPush` is a plain HTTPS request function with wildcard origin and no `enforceAppCheck`.

Impact: scripted clients with Firebase ID tokens can call the endpoint from arbitrary origins.

Recommended fix: use `onRequest({ enforceAppCheck: true, cors: [...] }, handler)` or callable functions with App Check; add rate limiting.

Verification: request without App Check token is rejected; source/contract test checks `enforceAppCheck`.

21. Tab navigation state and URL can drift.

Evidence: root route reads query params; tab taps mutate local state; `didUpdateWidget` updates only `initialTab`, not `initialSocialTab`.

Impact: browser/back/deep-link state can disagree with selected tab/subtab.

Recommended fix: drive tab changes through route locations and update both tab and social tab when widget props change.

Verification: navigation tests for `/?tab=social&socialTab=leaderboard` and subsequent social-subtab route changes.

22. Route builders do not encode query strings.

Evidence: `AppRouteLocations` manually concatenates query strings, including raw `audioUrl`.

Impact: URLs containing `?`, `&`, `=` or tokens can break deep-link parsing and voice note playback.

Recommended fix: construct route strings with `Uri(path: ..., queryParameters: ...)`.

Verification: unit test with audio URL containing query characters round-trips.

23. Light theme contract is undermined by hardcoded dark presentation.

Evidence: app uses `ThemeMode.system`, while main/session screens hardcode dark surfaces/colors.

Impact: light-mode users receive mixed Material theme and dark custom screens.

Recommended fix: either intentionally force dark mode or migrate presentation colors to `Theme.of(context).colorScheme`.

Verification: golden/smoke tests under light and dark modes.

24. Reduced motion is only partially honored.

Evidence: route transitions read `MediaQuery.disableAnimations`, but looping/pulsing/shimmer animations do not consistently check it.

Impact: users requesting reduced motion still get repeated motion effects.

Recommended fix: centralize reduced-motion behavior and skip or reduce looped animations/shimmer/pulses.

Verification: widget tests with `MediaQuery(disableAnimations: true)`.

25. Matchmaking page can overflow on small height or large text.

Evidence: matchmaking uses fixed `Column` layout with `Spacer`s and no scroll fallback.

Impact: accessibility text scaling, landscape phones, and small devices can hide controls.

Recommended fix: wrap in `LayoutBuilder` plus `SingleChildScrollView`, or use slivers.

Verification: widget test at small viewport and text scale 2.0 with no overflow.

26. iOS push entitlement is not visible.

Evidence: Info.plist enables background remote notification mode, but no `aps-environment` / entitlements wiring was found.

Impact: APNs/FCM delivery can fail on device/TestFlight.

Recommended fix: add Runner entitlements with `aps-environment`, enable push/background modes in signing, and wire `CODE_SIGN_ENTITLEMENTS`.

Verification: signed IPA entitlements include APNs environment.

27. Offline queue durability is weak for app-scale data.

Evidence: offline queue and failed operations are persisted in `SharedPreferences`.

Impact: large payloads, ordered replay, crash-safe sync, and exactly-once behavior are fragile.

Recommended fix: move queue to SQLite/Isar/Hive with operation IDs, idempotency keys, and bounded payload sizes.

Verification: kill app mid-sync and assert exactly-once server state after reconnect.

28. Startup does too much before first frame.

Evidence: `main()` initializes Firebase, env, App Check, notifications, storage, and offline handlers before `runApp`.

Impact: cold start can be delayed by plugin/network work.

Recommended fix: keep only mandatory initialization before `runApp`; defer notifications/offline sync behind splash or post-frame initialization.

Verification: profile cold start on low-end Android and iOS in profile mode.

29. Functions dependency audit has one critical vulnerability.

Evidence: `npm audit --json` reports 13 vulnerabilities, including critical transitive `protobufjs` and moderate Firebase/Admin transitive advisories.

Impact: backend dependencies need security review before release.

Recommended fix: update function dependencies in a dedicated branch, verify Firebase Functions compatibility, and rerun `npm audit`.

Verification: `npm audit` reports no critical/high vulnerabilities, or documented accepted residual risk.

30. Dependency drift is large.

Evidence: `flutter pub outdated` reports 48 locked packages behind upgradable versions, 41 constraints older than resolvable versions, and discontinued transitive `js`.

Impact: future platform/security upgrades become harder and riskier.

Recommended fix: create a dependency upgrade lane: patch/minor first, then planned major upgrades with full device testing.

Verification: `flutter pub outdated` shows reduced drift and CI/device suite passes.

31. Integration and cutover evidence is incomplete.

Evidence: migration quickstart/security reports still record blocked device/security verification and `TBD` post-cutover dates.

Impact: migration should not be considered production-proven.

Recommended fix: run integration/security tests on real Android/iOS devices, attach logs, and complete cutover evidence.

Verification: device-backed integration logs and signed-off reports exist.

32. Coverage and integration are not CI gates.

Evidence: GitHub Actions runs analyze and unit/widget tests only. No coverage, integration, or layer-validation step was found.

Impact: architecture, device-flow, and coverage regressions can slip through.

Recommended fix: add `flutter test --coverage`, layer validation, coverage artifacts, and scheduled/device integration jobs.

Verification: CI produces `lcov.info`, layer-validation output, and integration logs.

### Low

33. Duplicate Android `MainActivity` exists.

Evidence: active `com.zyntro.app` activity exists alongside stale-looking `com.zyntro.zyntro_flutter` activity.

Impact: package/flavor changes can accidentally reference the wrong entrypoint.

Recommended fix: remove the stale activity or document why both are needed.

Verification: merged manifest points only at the intended activity.

34. Navigation controls lack reliable semantics.

Evidence: bottom nav, session FAB, and several cards use raw gesture wrappers.

Impact: screen readers and keyboard/focus traversal may not expose controls as buttons/tabs.

Recommended fix: use `Semantics`, `InkWell`, or Material buttons with labels/selected states.

Verification: semantics tests for Feed/Social/Profile/session FAB/workout cards.

35. Sensitive release artifacts/check reports exist in repo/workspace.

Evidence: `git ls-files` shows `android/android_keys.txt` and `keytool_report.txt`; local signing files also exist outside the tracked list.

Impact: signing metadata in history and local keystores increase accidental leak risk.

Recommended fix: review tracked reports for sensitive material, remove/rotate if needed, and keep keystores only in CI secrets.

Verification: `git log --all -- android/key.properties android/app/zyntro-release.jks android/android_keys.txt keytool_report.txt .env*`.

## Assumptions

- The audit intentionally did not change production code.
- Existing dirty worktree changes were treated as user-owned and left untouched.
- No live Firebase, Stripe, or production data checks were performed.
- `functions/node_modules` and generated build artifacts were excluded from source review except dependency metadata and verification output.
