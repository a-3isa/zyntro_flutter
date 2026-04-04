# Project Weak-Point Audit

Date: 2026-03-30
Scope: startup and release safety, Firestore access rules, notification correctness, architecture drift, and test quality.

## Implemented Remediations

### Blocker
- Fixed App Check provider selection in `lib/main.dart` by routing through `lib/app/app_runtime_config.dart` so production uses hardened providers and non-production uses debug providers.
- Disabled verbose router diagnostics outside debug builds in `lib/app/navigation/app_router.dart`.
- Stopped swallowing uncaught async errors in `lib/utils/global_error_handler.dart` by returning `false` from `PlatformDispatcher.instance.onError`.
- Removed Android release fallback to debug signing and dropped the floating Facebook Android SDK dependency from `android/app/build.gradle.kts`.

### High
- Moved in-app notifications to `users/{userId}/notifications` in `lib/services/notification_service.dart` and aligned notifications page call sites with the new user-scoped methods.
- Added explicit Firestore rules for `users/{userId}/settings/{settingId}`, `users/{userId}/devices/{deviceId}`, and `users/{userId}/notifications/{notificationId}` in `firebase/firestore.rules`.
- Fixed missing `turn_change` notification parsing and introduced `NotificationType.unknown` so unsupported payloads no longer masquerade as session invites.
- Migrated the session room screen to read auth directly from `features/auth/auth_providers.dart`, removing its dependency on the legacy auth service shim.
- Replaced the floating `intl: any` dependency with `intl: ^0.20.2` in `pubspec.yaml`.
- Tightened root leaderboard event updates so clients can only increment `participantCount` as part of the same batched write that creates their `joinedEvents/{eventId}` record.
- Replaced the disabled client-side push queue with a server-owned HTTPS delivery path backed by Firebase Functions and FCM token pruning.

### Medium
- Removed generated or placeholder comments from `lib/services/notification_service.dart`.
- Replaced the placeholder `test/services/services_test.dart` with focused tests for runtime config, notification contracts, Firestore rules contracts, notification preferences UI behavior, and the new hardening boundaries.

## Residual Risks

### High
- The new push backend lives under `functions/`, and the `zynrto` project now has the required Functions APIs enabled, but the first deployment still failed because the build service account is missing the IAM permissions needed to complete Cloud Build. The mobile client now targets the backend endpoint and no longer falls back to insecure client-owned delivery.
- The temporary shim file `lib/services/auth_service.dart` still exists as cleanup debt until the rest of the tree is audited for dead compatibility code.

### Medium
- `.env`, `.env.dev`, `.env.staging`, and `.env.prod` are still bundled as Flutter assets in `pubspec.yaml`. If any of those files contain secrets, they remain recoverable from a shipped build.
- `lib/utils/global_error_handler.dart` still only logs locally and shows snackbars. Crash reporting is not wired, so production failures are harder to trace after the app rethrows them.
- The notification preferences model still maps `turnChange` to the `sessionInvites` toggle. That is intentional for now, but it remains a product coupling that may surprise users if turn notifications need independent control later.

### Cleanup
- The Firestore rules coverage is contract-based and string-based today. There are no emulator-backed allow and deny tests yet, so rule behavior is only partially protected.
- The Functions backend is source-tested, but there is no emulator or deployed smoke test yet for the live `deliverNotificationPush` endpoint.

## Verification Coverage Added
- `test/app/app_runtime_config_test.dart`
- `test/services/notification_service_contract_test.dart`
- `test/firebase/firestore_rules_contract_test.dart`
- `test/features/notifications/presentation/notification_preferences_page_test.dart`
- `test/services/leaderboard_service_contract_test.dart`
- `test/services/notification_delivery_boundary_test.dart`
- `test/services/push_delivery_backend_contract_test.dart`
- `test/services/session_invite_delivery_contract_test.dart`
- `test/features/session/presentation/session_room_auth_contract_test.dart`

## Recommended Next Order
1. Grant the missing Cloud Build permissions to the function build service account, redeploy `deliverNotificationPush`, then verify end-to-end delivery on real devices.
2. Delete the temporary `lib/services/auth_service.dart` compatibility shim once the rest of the tree is confirmed to no longer reference it.
3. Add Firebase emulator tests for the tightened Firestore rules and the HTTPS push endpoint.
4. Decide whether environment asset bundling is intentional; if not, remove the extra `.env.*` assets from the shipped bundle.
5. Wire real crash reporting before broad release validation.
