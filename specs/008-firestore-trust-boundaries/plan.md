# Implementation Plan: Firestore trust boundaries (users list privacy)

**Branch**: `008-firestore-trust-boundaries` | **Date**: 2026-09-17 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/008-firestore-trust-boundaries/spec.md`  
**Audit**: Z-SEC-001 / Z-ENH-044 (`docs/audits/2026-09-17-full-audit-findings.json`)

## Summary

Close the Critical privacy hole where `users` `allow get` uses `canReadUserProfile` but `allow list: if isAuthenticated()` lets any signed-in client query private profiles. Tighten list rules so private docs are not enumerable; keep public username search working via a rules-safe query constraint on the client; prove with emulator tests before any further rules deploy.

## Technical Context

**Language/Version**: Dart SDK ^3.10.4 (Flutter 3.10+), Node.js 22 (rules unit tests / Functions already on 22)  
**Primary Dependencies**: `cloud_firestore`, Firebase Security Rules, `@firebase/rules-unit-testing`, existing `UserService`  
**Storage**: Cloud Firestore — `users/{userId}`, `usernames/{username}`, `follows/{id}`  
**Testing**: `test/rules/*.rules.test.mjs` via `npm test --prefix test/rules`; Dart contract tests under `test/firebase/`; optional `UserService` unit/fake tests  
**Target Platform**: Android and iOS (rules/backend slice; no native UI required)  
**Project Type**: Mobile app + Firebase backend  
**Performance Goals**: Username search remains ≤10 results; no new unbounded `users` listeners  
**Constraints**: Firestore query+rules coupling (a query that *could* return an unauthorized doc fails entirely); `get()` inside list rules for followers is costly — followers keep using `get` by uid, not list  
**Scale/Scope**: 1 rules change block, 1–2 client call sites (`searchUsers` + any similar list), emulator tests, optional index if new equality filter requires it

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-design

| Principle | Assessment | Verdict |
|-----------|------------|---------|
| I. Feature-Slice Scope Discipline | Only users list/search privacy. Scores/mode/notifications out of scope. | PASS |
| II. Evidence-First Cutover | Emulator private-list deny + public search allow required before deploy (SC-001–SC-005). | PASS |
| III. Security and Access Integrity | Fixes Critical Z-SEC-001; no privileged field write changes. | PASS |
| IV. Operational Safety and Reversibility | Kill switch = redeploy previous `firestore.rules` from git. Discovery breakage is the rollback trigger. | PASS |
| V. Independent Deliverability | US1 alone closes the hole; US2 restores discovery; US3 verifies owner/mod paths. | PASS |

### Post-design re-check

| Principle | Assessment | Verdict |
|-----------|------------|---------|
| I | Design uses constrained `users` list + client `isPrivate == false` filter — no new microservice. Public projection collection deferred unless equality filter proves insufficient. | PASS |
| II | Contracts require emulator cases before deploy; CI/docs note predeploy test gate. | PASS |
| III | Approved followers retain `get`; list never grants stranger access to private docs. | PASS |
| IV | Rollback is prior rules revision; no irreversible data migration required if `isPrivate` already present. | PASS |
| V | Stories remain independently testable. | PASS |

## Project Structure

### Documentation (this feature)

```text
specs/008-firestore-trust-boundaries/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── users-list-acl.md
└── tasks.md              # /speckit-tasks
```

### Source Code (repository root)

```text
firebase/firestore.rules
firebase/firestore.indexes.json          # only if new composite needed
lib/services/user_service.dart           # searchUsers query constraints
lib/features/social/**                   # callers of search if any
test/rules/social.rules.test.mjs         # or new users_privacy.rules.test.mjs
test/firebase/firestore_rules_contract_test.dart
test/services/user_service_search_test.dart   # optional fake_cloud_firestore
.github/workflows/flutter-ci.yml         # ensure rules tests gate deploy job if present
```

**Structure Decision**: Existing Flutter + Firebase layout; no new app package. Prefer extending `test/rules/social.rules.test.mjs` or a dedicated `users_privacy.rules.test.mjs` for clarity.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | — | — |
