# Session Invite Delivery Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make paired session creation and invitation delivery work securely from host Start through invitee Accept/Decline.

**Architecture:** Firestore grants the pending invitee read-only access to the invited session. The authenticated Cloud Function owns cross-user notification creation and push delivery, while a foreground Flutter listener turns new durable session invitations into dialogs.

**Tech Stack:** Flutter, Riverpod, GoRouter, Cloud Firestore rules, Firebase Admin SDK, Cloud Functions v2, Node.js 22.

---

### Task 1: Add failing invitation contracts

**Files:**
- Modify: `test/firebase/firestore_rules_contract_test.dart`
- Modify: `test/services/session_invite_delivery_contract_test.dart`
- Create: `test/features/session/presentation/session_invite_listener_contract_test.dart`
- Modify: `test/services/push_delivery_backend_contract_test.dart`

- [ ] Assert pending invitees can read only their invited session.
- [ ] Assert session creation awaits backend invitation delivery.
- [ ] Assert the backend writes durable recipient notifications before push-token handling.
- [ ] Assert the app shell mounts a foreground listener with expiry and Accept/Decline behavior.
- [ ] Run the focused tests and confirm they fail for the missing behavior.

### Task 2: Repair Firestore session access

**Files:**
- Modify: `firebase/firestore.rules`

- [ ] Add a helper that recognizes the single pending invitee.
- [ ] Permit that invitee to read the session document without granting update access.
- [ ] Run the Firestore contract test.

### Task 3: Make backend delivery durable

**Files:**
- Modify: `functions/index.js`
- Modify: `lib/services/notification_service.dart`
- Modify: `lib/services/session_service.dart`

- [ ] Preserve complete session invitation context in the validated backend payload.
- [ ] Write the recipient notification through Admin SDK before checking device tokens.
- [ ] Return durable notification and push-delivery status.
- [ ] Route cross-user notifications exclusively through the backend endpoint.
- [ ] Await session invitation delivery and propagate delivery failures.
- [ ] Run notification and session service tests.

### Task 4: Show foreground invitation dialog

**Files:**
- Create: `lib/features/session/presentation/session_invite_listener.dart`
- Modify: `lib/features/main/presentation/main_shell.dart`

- [ ] Watch signed-in user notifications from the main shell.
- [ ] Ignore read, expired, and already-presented invitations.
- [ ] Present host/workout context with Decline and Accept actions.
- [ ] Mark handled notifications read and route Accept to the acceptance page.
- [ ] Run listener and invitation acceptance tests.

### Task 5: Verify and deploy

**Files:**
- Deploy: `firebase/firestore.rules`
- Deploy: `functions/index.js`

- [ ] Run focused Flutter tests and analyzer checks.
- [ ] Run Node syntax/source discovery and npm audit checks.
- [ ] Deploy Firestore rules and every exported Cloud Function to `zynrto`.
- [ ] Confirm every function is active on Node.js 22 and its unauthenticated HTTP boundary returns the expected rejection.
