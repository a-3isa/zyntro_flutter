# Zyntro Audit Remediation Roadmap

Date: 2026-05-02

## Phase 0: Stop Release Drift

Goal: prevent known-broken builds or unsafe releases from moving forward.

- Pin GitHub Actions and Codemagic to a Flutter version compatible with Dart `^3.10.4`, or intentionally lower the SDK constraint.
- Remove `ignore_failure: true` from Codemagic analyze/test steps.
- Decide whether the app uses native flavors. Either add `dev/staging/prod` native flavor support or remove all `--flavor` build commands.
- Fix the analyzer error in `session_invite_acceptance_page_test.dart`.
- Reconcile the theme palette contract and stale `StartSessionPage` tests.
- Treat tracked `.env*` and signing report files as exposed until reviewed and rotated.

Exit criteria:

- `flutter pub get`, `flutter analyze`, and the targeted failing tests pass locally.
- CI no longer uses a Flutter version too old for the Dart SDK constraint.
- Flavor build commands are either supported or removed.

## Phase 1: Close Critical Firebase Trust Gaps

Goal: prevent client-side privilege escalation and cross-user writes.

- Lock down `/users/{userId}` create/update schemas so clients cannot write moderator, payment, entitlement, score, or audit fields.
- Move global leaderboard entitlement granting behind backend-verified Stripe PaymentIntents/webhooks.
- Rewrite session update rules around host/server lifecycle control, invited-user acceptance, and narrow participant writes.
- Fix follow request transitions so followers cannot self-approve private follows.
- Make cross-user notification creation server-owned.
- Add Firebase Storage rules and wire them into `firebase.json`.

Exit criteria:

- Emulator tests cover moderator self-create, entitlement self-grant, session self-join, participant lifecycle mutation, follower self-approval, notification spoofing, and Storage upload/read rules.
- Client code no longer grants paid entitlements directly.

## Phase 2: Restore Mobile Release Readiness

Goal: make Android/iOS builds reproducible from a clean checkout.

- Inject or generate Firebase native config files in CI, or initialize Firebase through generated Dart options.
- Add iOS microphone usage copy and push notification entitlements.
- Add FCM token refresh and terminated-state initial-message handling.
- Replace mock Stripe purchase flow with backend PaymentIntent/webhook flow.
- Review duplicate Android `MainActivity` and remove/document the stale package.
- Move env handling away from bundled `.env*` assets.

Exit criteria:

- Clean Android debug/release builds complete.
- iOS archive has required privacy strings and APNs entitlements.
- Push notification lifecycle is verified in foreground, background, and terminated states.

## Phase 3: Fix User-Facing Flow Regressions

Goal: align navigation, session flow, and accessibility with expected product behavior.

- Preserve protected deep links through login/profile completion.
- Derive session room workout mode from session data, not default query params.
- Resume active sessions with the stored session type instead of hardcoded `gym`.
- Encode all route query strings with `Uri`.
- Drive main-shell tab/subtab selection through route state.
- Add reduced-motion handling to looped/pulsing/shimmer animations.
- Add scroll fallback for matchmaking on small screens and large text.
- Add semantics to custom navigation and card controls.

Exit criteria:

- Deep-link, resume, and route-encoding tests pass.
- Reduced-motion and small-screen widget tests pass.
- Accessibility semantics tests cover main navigation/session entry controls.

## Phase 4: Complete Architecture And Evidence

Goal: turn the clean-architecture migration into enforceable, repeated evidence.

- Continue feature-by-feature migration for feed, main, moderation, notifications, profile, session, settings, and social.
- Add layer validation and import-boundary checks to CI.
- Add coverage collection and artifact upload.
- Run integration/security flows on Android and iOS devices.
- Finish migration quickstart, security regression, and post-cutover metric reports.

Exit criteria:

- `scripts/validate_feature_layers.ps1` passes or explicitly excludes planned legacy areas.
- CI publishes coverage and layer-validation artifacts.
- Device-backed integration logs are attached to migration evidence.

## Phase 5: Dependency And Operational Hardening

Goal: reduce latent platform/security maintenance risk.

- Update Functions dependencies and clear critical/high npm audit findings.
- Run a Flutter dependency upgrade lane: patch/minor upgrades first, then major migrations.
- Replace `SharedPreferences` offline queue with durable storage and idempotent replay.
- Defer non-critical startup work until after first frame or splash.
- Add App Check enforcement, restricted CORS, and rate limiting to HTTPS functions.

Exit criteria:

- `npm audit` has no critical/high findings or documented accepted risk.
- `flutter pub outdated` drift is reduced and tracked.
- Offline queue survives app kill/restart with exactly-once replay checks.
- Cold-start profile data is captured on representative devices.
