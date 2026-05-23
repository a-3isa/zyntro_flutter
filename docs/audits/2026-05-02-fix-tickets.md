# Zyntro Audit Fix Tickets

Date: 2026-05-02

## Critical

### AUD-001: Deny client-created moderator privileges

Severity: Critical
Owner: Backend/Security

Problem: `/users/{userId}` create allows arbitrary fields, while moderator checks trust `users/{uid}.isModerator`.

Acceptance criteria:

- User create denies `isModerator`, `isBanned`, `bannedUntil`, and `banReason`.
- User update denies client writes to moderation fields.
- Moderator assignment is performed only by trusted backend/admin flow.
- Emulator test proves self-create with `isModerator: true` is denied.

### AUD-002: Move paid entitlement granting server-side

Severity: Critical
Owner: Backend/Payments

Problem: Flutter client code can grant `hasGlobalLeaderboardAccess` and mock payment success.

Acceptance criteria:

- Firestore rules deny client writes to entitlement, payment, transaction, score, and audit fields.
- PaymentIntent creation runs in authenticated backend code.
- Entitlement is granted only after verified Stripe webhook/payment confirmation.
- Emulator tests deny direct entitlement writes by the owning user.

### AUD-003: Repair native flavor/build configuration

Severity: Critical
Owner: Mobile/DevOps

Problem: CI and docs build `--flavor dev/staging/prod`, but Android/iOS native flavors are not defined.

Acceptance criteria:

- Either Android/iOS define `dev/staging/prod` flavors/schemes, or all `--flavor` commands are removed.
- GitHub Actions and Codemagic use commands that match native config.
- `flutter build apk --flavor prod --dart-define=ENV=prod --release` succeeds if flavors remain.
- `flutter build apk --dart-define=ENV=prod --release` succeeds if flavors are removed.

### AUD-004: Align CI Flutter version with Dart constraint

Severity: Critical
Owner: DevOps

Problem: CI pins Flutter 3.24.0 while `pubspec.yaml` requires Dart `^3.10.4`.

Acceptance criteria:

- GitHub Actions and Codemagic use a Flutter version with Dart 3.10.4+.
- CI `flutter --version` is logged.
- CI `flutter pub get` succeeds from a clean checkout.

### AUD-005: Remove secret-bearing env assets from source and app bundle

Severity: Critical
Owner: Mobile/Security/DevOps

Problem: `.env*` files are tracked and bundled as Flutter assets.

Acceptance criteria:

- `.env*` files with sensitive values are removed from Git tracking and replaced with examples/templates.
- App bundle no longer contains `.env*` under `flutter_assets`.
- CI injects public runtime config safely.
- Exposed credentials are rotated where needed.

## High

### AUD-006: Lock down session mutation rules

Severity: High
Owner: Backend/Security

Problem: users can self-add to sessions and participants can mutate broad session state.

Acceptance criteria:

- Uninvited self-join is denied.
- Only host/server can change lifecycle fields such as `status`, `phase`, `activeUserId`, summaries, and invite lists.
- Invited acceptance requires the caller to be in `resource.data.invitedUserIds`.
- Emulator tests cover self-join, participant state mutation, and invited acceptance.

### AUD-007: Enforce private follow approval rules

Severity: High
Owner: Backend/Social

Problem: followers can self-approve private follow requests.

Acceptance criteria:

- Followers can create only valid pending requests when target privacy requires approval.
- Only followee can transition pending to approved.
- Emulator tests deny follower-side approval.

### AUD-008: Make cross-user notifications trusted-backend writes

Severity: High
Owner: Backend/Notifications

Problem: any authenticated user can create notifications under another user.

Acceptance criteria:

- Client cannot create notifications for another user.
- Cross-user notification creation occurs through Cloud Functions or trusted triggers.
- Emulator test denies user A writing `/users/B/notifications/*`.

### AUD-009: Add Firebase Storage rules

Severity: High
Owner: Backend/Mobile

Problem: app uploads media but repo has no `storage.rules` or deploy config.

Acceptance criteria:

- `storage.rules` exists and is referenced by `firebase.json`.
- Rules enforce auth, owner/session membership, content type, size, and path ownership.
- Storage emulator tests cover profile photos, post media, voice notes, bad content type, oversize files, and arbitrary path uploads.

### AUD-010: Make Firebase initialization reproducible in clean CI

Severity: High
Owner: Mobile/DevOps

Problem: native Firebase config files are ignored/untracked and CI only writes `.env`.

Acceptance criteria:

- Android and iOS builds work from a clean checkout without manual local Firebase files.
- CI either injects native Firebase files or app initializes with generated Dart options.
- Clean-clone build verification is documented.

### AUD-011: Add missing iOS microphone privacy declaration

Severity: High
Owner: Mobile

Problem: voice recording code requests mic access, but iOS lacks `NSMicrophoneUsageDescription`.

Acceptance criteria:

- `ios/Runner/Info.plist` includes microphone usage copy.
- Android merged manifest includes required audio permission.
- Real iOS device can start a voice note from fresh permission state.

### AUD-012: Implement production Stripe payment path

Severity: High
Owner: Backend/Payments

Problem: PaymentIntent creation is mocked in client code and entitlement grant is client-side.

Acceptance criteria:

- Client requests PaymentIntent from authenticated backend endpoint.
- Stripe webhook confirms payment before entitlement write.
- Client mock path cannot grant production entitlement.
- Stripe test-mode end-to-end verification passes.

### AUD-013: Complete FCM token and tap lifecycle

Severity: High
Owner: Mobile/Notifications

Problem: token refresh and terminated-state message handling are missing.

Acceptance criteria:

- `onTokenRefresh` updates stored device token.
- `getInitialMessage()` handles terminated notification taps.
- Foreground, background, and terminated notification flows are device-tested.

### AUD-014: Preserve protected deep links through auth

Severity: High
Owner: Frontend/Auth

Problem: protected routes redirect to login and lose the intended destination.

Acceptance criteria:

- Redirect stores original URI as `from` or equivalent.
- Login/profile completion returns to the protected destination.
- Widget test covers session invite deep link while signed out.

### AUD-015: Derive session room type from session data

Severity: High
Owner: Frontend/Session

Problem: room defaults missing type to `strength`; resume hardcodes `gym`.

Acceptance criteria:

- Session room mode is derived from current session data.
- Active-session resume uses stored session type.
- Tests cover non-gym room deep links and non-gym active resume.

### AUD-016: Restore analyzer and test baseline

Severity: High
Owner: Engineering

Problem: `flutter analyze` and targeted tests are failing.

Acceptance criteria:

- `AuthUserEntity` test compile issue is fixed.
- Theme palette source of truth is decided and tests/implementation are aligned.
- Start-session tests match current intended UI behavior.
- `flutter analyze` and `flutter test` complete successfully locally.

### AUD-017: Enforce clean architecture beyond auth

Severity: High
Owner: Architecture

Problem: layer validation fails for most features, and presentation code imports root services/Firebase.

Acceptance criteria:

- Non-auth feature migration status is documented.
- CI runs layer validation.
- Planned legacy exceptions are explicit, temporary, and tracked.
- At least one next non-auth feature is migrated end-to-end as a template.

### AUD-018: Make Codemagic quality gates mandatory

Severity: High
Owner: DevOps

Problem: Codemagic ignores analyze/test failures in production workflows.

Acceptance criteria:

- `ignore_failure: true` is removed from production analyze/test steps.
- A deliberately failing test blocks publish in a dry run or test workflow.

## Medium

### AUD-019: Enforce post visibility in rules

Severity: Medium
Owner: Backend/Social

Problem: all authenticated users can read all posts regardless of visibility/privacy.

Acceptance criteria:

- Rules enforce public, author, approved follower, and buddy/friends visibility.
- Emulator tests cover unrelated authenticated reads against restricted posts.

### AUD-020: Enforce App Check and CORS on push function

Severity: Medium
Owner: Backend/Security

Problem: HTTPS function has wildcard CORS and no App Check enforcement.

Acceptance criteria:

- Function uses App Check enforcement or callable function with App Check.
- CORS is restricted to intended origins where applicable.
- Source/contract test verifies App Check configuration.

### AUD-021: Drive main-shell tabs from route state

Severity: Medium
Owner: Frontend

Problem: local tab state can drift from URL/deep-link state.

Acceptance criteria:

- Tab/subtab changes update route location.
- `didUpdateWidget` handles both main tab and social subtab.
- Navigation tests cover social subtab route changes.

### AUD-022: Encode route query parameters

Severity: Medium
Owner: Frontend

Problem: route builders manually concatenate query strings.

Acceptance criteria:

- Route builders use `Uri` and query parameters.
- Audio URLs containing `?`, `&`, `=` round-trip through parsing.

### AUD-023: Decide light/dark theme contract

Severity: Medium
Owner: Frontend/Design

Problem: app uses system theme while key screens hardcode dark colors.

Acceptance criteria:

- Product decision is documented: forced dark or full light/dark support.
- Tests/goldens cover the chosen behavior.

### AUD-024: Honor reduced motion across custom animations

Severity: Medium
Owner: Frontend/Accessibility

Problem: repeated/pulsing/shimmer animations ignore reduced motion in several screens.

Acceptance criteria:

- Central reduced-motion helper exists.
- Looping custom animations and shimmer respect `MediaQuery.disableAnimations`.
- Widget tests cover reduced-motion mode.

### AUD-025: Add small-screen scroll fallback to matchmaking

Severity: Medium
Owner: Frontend/Mobile

Problem: matchmaking layout can overflow with small height or large text.

Acceptance criteria:

- Matchmaking content scrolls or relayouts on constrained height.
- Widget test at small viewport and text scale 2.0 has no overflow.

### AUD-026: Add iOS push entitlements

Severity: Medium
Owner: Mobile

Problem: background push mode is present, but APNs entitlement wiring is not visible.

Acceptance criteria:

- Runner entitlements include APNs environment.
- Xcode project wires `CODE_SIGN_ENTITLEMENTS`.
- Signed IPA entitlements verification is documented.

### AUD-027: Replace SharedPreferences offline queue

Severity: Medium
Owner: Mobile/Data

Problem: durable ordered offline queue uses `SharedPreferences`.

Acceptance criteria:

- Offline operations move to durable local store.
- Operation IDs and idempotency keys prevent duplicate server effects.
- Kill/restart offline replay test passes.

### AUD-028: Defer non-critical startup work

Severity: Medium
Owner: Mobile/Performance

Problem: many plugin/network initializations run before first frame.

Acceptance criteria:

- Only mandatory initialization blocks `runApp`.
- Notifications/offline sync initialize after first frame or during splash.
- Profile-mode cold-start measurements are captured before/after.

### AUD-029: Clear Functions dependency vulnerabilities

Severity: Medium
Owner: Backend/DevOps

Problem: `npm audit` reports 13 vulnerabilities, including one critical transitive issue.

Acceptance criteria:

- Functions dependencies are updated in a compatibility-tested branch.
- `npm audit` reports no critical/high findings, or residual risk is documented.
- Push function contract tests still pass.

### AUD-030: Reduce Flutter dependency drift

Severity: Medium
Owner: Engineering

Problem: many Flutter packages are locked or constrained behind newer resolvable versions.

Acceptance criteria:

- Patch/minor upgrade PR passes full local/CI checks.
- Major upgrade plan exists for Firebase, Riverpod, GoRouter, Stripe, notifications, and record.
- Discontinued transitive `js` is removed through dependency upgrades where possible.

### AUD-031: Complete migration evidence

Severity: Medium
Owner: QA/Architecture

Problem: integration and cutover docs still record blocked/TBD evidence.

Acceptance criteria:

- Android and iOS integration/security tests are run on devices.
- Logs are attached to migration evidence docs.
- Post-cutover metrics have concrete dates and measurements.

### AUD-032: Add coverage/integration gates

Severity: Medium
Owner: DevOps/QA

Problem: CI lacks coverage, integration, and layer-validation gates.

Acceptance criteria:

- CI runs `flutter test --coverage`.
- CI uploads `lcov.info`.
- CI runs layer validation.
- Device integration strategy is documented or scheduled.

## Low

### AUD-033: Remove or document duplicate Android MainActivity

Severity: Low
Owner: Mobile

Problem: two Android `MainActivity.kt` packages exist.

Acceptance criteria:

- Stale activity is removed or documented.
- Merged manifest points to the intended package.

### AUD-034: Add semantics to custom navigation controls

Severity: Low
Owner: Frontend/Accessibility

Problem: custom gesture controls may not expose button/tab semantics.

Acceptance criteria:

- Main nav, session FAB, workout cards, and invite type cards expose proper semantics.
- Semantics tests cover labels, button role, and selected state.

### AUD-035: Review signing/env artifacts in history

Severity: Low
Owner: Security/DevOps

Problem: signing reports and env files are tracked; local signing files exist in workspace.

Acceptance criteria:

- History is reviewed for private material.
- Exposed secrets/keys are rotated if needed.
- Repo only tracks safe templates and documentation.
