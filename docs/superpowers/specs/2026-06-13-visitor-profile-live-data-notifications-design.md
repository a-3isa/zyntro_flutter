# Visitor Profile, Live Data, and Follow Notifications

## Goal

Improve the visitor profile using the approved social-first layout, keep profile statistics and edited values current without restarting the app, and deliver both in-app and push notifications for public follows.

## Design

The visitor header uses a compact horizontal identity row with avatar, rank, name, username, workout chip, and an explicit `Follow back` action when the target already follows the viewer. Stats sit in a rounded surface card and all text styles explicitly disable decoration. Flutter debug paint is disabled at startup so debug baselines and bounds cannot appear in screenshots.

Profile documents, follower counts, and following counts use Firestore snapshot streams instead of one-time reads. Existing session and streak calculations remain asynchronous, but profile edits and follow mutations invalidate their dependent providers immediately.

Public follows use a new `newFollower` notification type. `FollowService.followUser` calls one notification method for public accounts and retains `followRequest` for private accounts. The notification service writes the user's notification document and invokes the existing authenticated push-delivery endpoint in parallel.

## Verification

Tests cover notification type serialization, public-follow notification dispatch, reactive profile/count providers, visitor header source contracts, and debug-paint configuration. Existing profile, follow, notification, and push-delivery tests must remain green.
