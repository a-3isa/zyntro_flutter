# Push Delivery Design

Date: 2026-03-30

## Goal
Re-enable remote push delivery without reopening the client-writable `pushQueue` path.

## Architecture
- Keep in-app notifications in Firestore under `users/{userId}/notifications`.
- Replace client `pushQueue` writes with an authenticated Firebase HTTPS function named `deliverNotificationPush`.
- The Flutter app sends typed push requests to the HTTPS endpoint after creating the in-app notification.
- The function verifies the Firebase ID token, validates the authenticated caller against current Firestore domain state, loads device tokens from `users/{userId}/devices`, and sends FCM with the Admin SDK.
- Firestore rules continue to deny all client access to `pushQueue`.

## Supported Notification Types
- `session_invite`
- `turn_change`
- `voice_note`
- `follow_request`
- `follow_accepted`
- `post_like`
- `post_comment`

## Validation Strategy
- `session_invite`: caller must be the session host and recipient must be listed in `invitedUserIds`.
- `turn_change`: caller and recipient must both be participants and recipient must be the session `activeUserId`.
- `voice_note`: caller and recipient must both be session participants.
- `follow_request`: a pending follow doc must exist from caller to recipient.
- `follow_accepted`: an approved follow doc must exist where recipient is the original requester.
- `post_like`: post author must match recipient and caller must have a reaction doc on the post.
- `post_comment`: post author must match recipient and the referenced comment doc must belong to the caller.

## Data Model Changes
- Add `invitedUserIds` to session creation writes so the backend can validate invite pushes.
- Pass `commentId` into post-comment push requests so the backend can validate the actual comment document.

## Client Changes
- Use the existing `http` and Firebase Auth dependencies.
- Inject auth and HTTP client support into `NotificationService`.
- Replace the disabled `_queuePushNotification` behavior with an authenticated HTTPS request builder that sends typed payloads.

## Backend Changes
- Add a `functions/` Firebase Functions project.
- Export `deliverNotificationPush` via `firebase-functions/v2/https` using `onRequest`.
- Use `firebase-admin` to verify ID tokens, read Firestore, read device tokens, send multicast messages, and prune invalid tokens.

## Verification
- Flutter contract tests for the client boundary and validation data shape.
- Source-contract test for the backend HTTPS export and token delivery logic.
- Focused Flutter test suite plus full-workspace `flutter analyze`.
