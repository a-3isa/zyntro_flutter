# zyntro_flutter Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-09-17

## Active Technologies
- Dart SDK `^3.10.4` with Flutter 3.10+ (CI may pin a specific patch) + `flutter_riverpod`, `go_router`, `firebase_auth`, `cloud_firestore`, `shared_preferences`, `mocktail`, `flutter_test`, `integration_test`
- Cloud Firestore: `sessions` (+ `plans`/`events`/`presence`), `workouts`, `users`/`usernames`/`follows`, `posts`, `matchmaking_queue`, `buddyPairs`, exercise catalog, notifications, `rateLimits` (Admin-only)
- Node.js 22 for Firestore rules unit tests and Cloud Functions

## Project Structure

```text
lib/
test/
firebase/
functions/
specs/
docs/audits/
```

## Commands

```bash
flutter analyze
flutter test
cd test/rules && npm test   # Firestore rules emulator suite
firebase deploy --only "functions,firestore:rules"
```

## Code Style

Dart SDK `^3.10.4` with Flutter 3.10+: Follow standard conventions

## Recent Changes
- 024-android-signing-guard: release signingConfig only when `key.properties` exists (Z-AND-003)
- 023-push-rate-limit: deliverNotificationPush 30/min + 15s dedupe (Z-FN-001); deployed
- 022-text-scale-cap: text scale ceiling 2.0x (Z-A11Y-003)
- 021-reduced-motion: premium glow/shimmer/confetti honor OS reduce-motion (Z-UI-001)
- 020-set-submit-guard: in-flight set submit + stable offline event ids (Z-RT-004)
- 019-auth-deeplink-restore: post-login `from` restore (Z-AUTH-007)
- 018-signout-cache-clear: central sign-out clears caches/analytics (Z-AUTH-003 / Z-DATA-003)
- 017-email-verify-gate: password social writes need emailVerified (Z-AUTH-002); rules deployed
- 016–011: buddy CF push, auth enum hardening, forced-update, in-app review, match/turn integrity, audit quick wins
- 010–008: score integrity, mode derivation, firestore trust boundaries


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:
`specs/011-audit-quick-wins/spec.md`

Ongoing Critical/High audit closure continues on stacked feature branches
`012`–`024` from `docs/audits/2026-09-17-full-audit-findings.json`.
Deferred: `Z-IOS-001` (aps-environment development).
<!-- SPECKIT END -->
