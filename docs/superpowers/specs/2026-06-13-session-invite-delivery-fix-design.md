# Session Invite Delivery Fix Design

## Goal

When a host taps Start with one selected mutual friend, create the paired session, deliver a durable in-app invitation and push notification, and show the invitee an immediate Accept/Decline dialog while the invite remains valid.

## Architecture

- Firestore session rules allow the host and participants to read a session, plus the single user named in `invitedUserIds` while the invitation is pending.
- Client applications remain unable to write another user's notification documents.
- `deliverNotificationPush` validates the authenticated caller and domain object, writes the recipient notification with Admin SDK, and then attempts push delivery.
- `SessionService.createSession` waits for invite delivery and reports failure instead of discarding it.
- A foreground listener mounted around the main shell watches the signed-in user's notification stream and presents one unexpired session invitation at a time.

## Error Handling

- Session creation permission errors retain a user-facing Firebase permissions message.
- Invite delivery errors are surfaced to the host as delivery failures.
- A recipient without a push token still receives the durable in-app invitation.
- Expired or already-read invitations do not open dialogs.

## Verification

- Contract and service tests cover pending-invite reads, backend-owned notification writes, awaited delivery, foreground dialog routing, and expiry filtering.
- Deploy Firestore rules and all exported Functions.
- Verify function discovery, Node source loading, deployment state, runtime, and HTTP authentication boundaries.
