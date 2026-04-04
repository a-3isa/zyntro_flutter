# Push Delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-enable secure remote push delivery through an authenticated Firebase HTTPS backend instead of client-writable Firestore queue documents.

**Architecture:** Flutter continues to create in-app notifications locally, then posts a typed request to an authenticated Firebase HTTPS function for push delivery. The function validates the bearer token, checks the authenticated caller against Firestore domain state, reads recipient device tokens, and sends FCM through the Admin SDK. Firestore rules continue to block `pushQueue`.

**Tech Stack:** Flutter, Riverpod, Firebase Cloud Functions, firebase-admin, firebase-functions v2, Cloud Firestore, Firebase Cloud Messaging

---

### Task 1: Add failing boundary tests

**Files:**
- Modify: `test/services/notification_delivery_boundary_test.dart`
- Create: `test/services/push_delivery_backend_contract_test.dart`
- Create: `test/services/session_invite_delivery_contract_test.dart`

- [x] Write failing tests for HTTPS client delivery, backend export, and session invite validation data.
- [x] Run the focused tests and confirm they fail for the expected missing backend/client boundary reasons.

### Task 2: Wire the Flutter client to authenticated HTTPS delivery

**Files:**
- Modify: `lib/services/notification_service.dart`
- Modify: `lib/services/session_service.dart`
- Modify: `lib/services/post_service.dart`

- [x] Keep the existing Flutter dependency set and route push delivery through an authenticated HTTPS request.
- [x] Inject auth and HTTP client support into `NotificationService` and replace the disabled queue path with a typed HTTPS request.
- [x] Add `invitedUserIds` to session creation writes for invite validation.
- [x] Pass `commentId` into post-comment delivery requests.
- [x] Run the focused tests and make them pass.

### Task 3: Add the Firebase Functions backend

**Files:**
- Create: `functions/package.json`
- Create: `functions/index.js`
- Modify: `firebase.json`
- Modify: `.gitignore`

- [x] Add a minimal Firebase Functions project with `deliverNotificationPush`.
- [x] Implement validation helpers for the supported notification types.
- [x] Send FCM notifications to `users/{userId}/devices` tokens and prune invalid tokens.
- [x] Update repo config to recognize the functions source.
- [x] Run the backend source-contract test and Flutter-focused tests.

### Task 4: Document and verify deployment

**Files:**
- Modify: `README.md`
- Modify: `DEPLOYMENT_GUIDE.md`
- Modify: `docs/project_weak_point_audit.md`

- [x] Document the new functions deployment step and HTTPS push architecture.
- [x] Update the audit report to reflect that push is re-enabled through a backend-owned path.
- [ ] Run the combined focused test suite and full-workspace `flutter analyze`.
