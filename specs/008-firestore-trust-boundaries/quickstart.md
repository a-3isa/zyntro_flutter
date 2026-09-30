# Quickstart: 008-firestore-trust-boundaries

## Prerequisites

- Flutter SDK matching repo; Node for `test/rules`
- Java + `firebase-tools` for rules emulator
- Branch `008-firestore-trust-boundaries`

## Verify (local)

```powershell
# Rules emulator suite (includes new privacy cases)
npm test --prefix test/rules

# Optional: Dart analyze/tests touching UserService
flutter analyze lib/services/user_service.dart
flutter test test/firebase/firestore_rules_contract_test.dart
```

## Manual discovery smoke (optional)

1. Two accounts: public Charlie, private Alice.
2. From Mallory, search Charlie’s username → appears.
3. Search Alice’s username → does not appear; opening Alice profile via uid without follow → permission denied / gated UI.

## Deploy (only after green)

```powershell
npm test --prefix test/rules
if ($LASTEXITCODE -ne 0) { throw "rules tests failed" }
firebase deploy --only firestore:rules --project zynrto
# If indexes added:
firebase deploy --only firestore:indexes --project zynrto
```

## Rollback

```powershell
git show HEAD~1:firebase/firestore.rules > firebase/firestore.rules
# or checkout the last known-good rules commit, then:
firebase deploy --only firestore:rules --project zynrto
```

## Evidence (2026-09-17)

- Emulator: `npm test --prefix test/rules` → **119 pass / 0 fail** (includes Z-SEC-001 list deny + public search allow).
- Contract: `flutter test test/firebase/firestore_rules_contract_test.dart` green.
- Client: `UserService.searchUsers` and `FollowService.getSuggestedUsers` constrain `isPrivate == false`; friend/user whereIn lookups converted to per-doc `get`.
- Deploy: `firebase deploy --only firestore:rules,firestore:indexes --project zynrto` after green tests.
- Finding **Z-SEC-001**: Fixed & verified (regression: `social.rules.test.mjs` privacy list cases).

