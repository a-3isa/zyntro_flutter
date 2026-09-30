# Visitor Profile Live Data and Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish the visitor profile, make profile values update live, and notify users when public accounts receive a follow.

**Architecture:** Use existing Riverpod providers backed by Firestore snapshot streams, retain local invalidation for derived values, and extend the existing notification service rather than introducing a second delivery path. Keep UI edits scoped to the existing profile header.

**Tech Stack:** Flutter, Dart, Riverpod, Cloud Firestore, Firebase Messaging, Flutter local notifications, Flutter tests.

---

### Task 1: Public Follow Notifications

**Files:**
- Modify: `lib/services/notification_service.dart`
- Modify: `lib/services/follow_service.dart`
- Modify: `functions/index.js`
- Test: `test/services/notification_service_contract_test.dart`
- Test: `test/services/follow_service_test.dart`
- Test: `test/services/push_delivery_backend_contract_test.dart`

- [ ] Add failing tests for `NotificationType.newFollower`, public follow dispatch, and backend push payload support.
- [ ] Run the focused tests and confirm failures are caused by missing public-follow support.
- [ ] Add `newFollower` serialization, preference routing, `notifyNewFollower`, and public follow invocation.
- [ ] Add the matching backend payload branch.
- [ ] Run focused notification and follow tests.

### Task 2: Reactive Profile Values

**Files:**
- Modify: `lib/features/profile/presentation/profile_page.dart`
- Modify: `lib/services/follow_service.dart`
- Modify: `lib/features/profile/presentation/edit_profile_page.dart`
- Test: `test/features/profile/presentation/profile_page_test.dart`

- [ ] Add failing source/provider tests requiring snapshot-backed profile and count providers.
- [ ] Add `watchFollowersCount` and `watchFollowingCount` streams.
- [ ] Convert profile/count providers to stream providers using Firestore snapshots.
- [ ] Invalidate current profile, auth profile, streak, sessions, rank, and counts after edit/follow mutations.
- [ ] Run profile and provider tests.

### Task 3: Visitor Profile Polish

**Files:**
- Modify: `lib/features/profile/presentation/profile_page.dart`
- Modify: `lib/main.dart`
- Test: `test/features/profile/presentation/profile_page_test.dart`
- Test: `test/app/startup_release_contract_test.dart`

- [ ] Add failing contracts for the social-first identity row, `Follow back`, rounded stat card, undecorated text, and disabled debug paint.
- [ ] Implement the compact visitor header while preserving existing actions and privacy behavior.
- [ ] Explicitly disable debug paint flags during startup.
- [ ] Run profile widget/source tests and startup tests.

### Task 4: Verification

- [ ] Run `dart format` on touched Dart files.
- [ ] Run focused profile, follow, notification, and startup tests.
- [ ] Run `flutter analyze` on touched Dart files.
- [ ] Run `git diff --check` and inspect the final diff for unrelated churn.
