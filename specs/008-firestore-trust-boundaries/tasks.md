# Tasks: Firestore trust boundaries (users list privacy)

**Input**: Design documents from `/specs/008-firestore-trust-boundaries/`  
**Status**: Implemented 2026-09-17

## Phase 1: Setup

- [x] T001 Spec/plan/research/contracts/quickstart written
- [x] T002 SPECKIT markers pointed at `specs/008-firestore-trust-boundaries/plan.md`

## Phase 2: Foundational

- [x] T003 Inventoried `users` queries (`searchUsers`, suggestions, whereIn in leaderboard/follow/cache/user_service)
- [x] T004 Added composites: `isPrivate+usernameLower`, `isPrivate+createdAt`

## Phase 3: US1 — Private list privacy

- [x] T005 Tightened `allow list` via `canListUserProfile()` (`isPrivate == false` explicit)
- [x] T006 Emulator cases in `test/rules/social.rules.test.mjs`
- [x] T007 Updated `test/firebase/firestore_rules_contract_test.dart`

## Phase 4: US2 — Public discovery

- [x] T008 `UserService.searchUsers` filters `isPrivate == false`
- [x] T009 Emulator public search allow
- [x] T010 whereIn → per-doc get in leaderboard, follow, user_cache, user_service; suggestions filter

## Phase 5: US3 — Owner/moderator

- [x] T011 Moderator get private Alice covered in emulator suite

## Phase 6: Polish

- [x] T012 CI `deploy-firebase-rules` runs `npm test` in `test/rules` before deploy
- [x] T013 Rules 119/0 + contract test green
- [x] T014 Deployed rules+indexes to `zynrto`
- [x] T015 Evidence noted in `quickstart.md`
