# Push delivery smoke checklist

**Related:** Z-FN-004  
**Owner:** engineering

Live HTTPS smoke cannot run unsigned from CI without App Check + Auth secrets. Use this checklist after deploying `deliverNotificationPush`:

1. Sign in on a staging device with App Check debug token registered.
2. Trigger a follow or session invite that calls `deliverNotificationPush`.
3. Confirm Cloud Logging shows `Delivered push notification.` (or `skipped` / `blocked` when expected).
4. Confirm the recipient gets an in-app notification doc under `users/{uid}/notifications`.

Contract tests under `functions/test/push_path_contracts.test.js` lock the gate order (App Check → auth → rate limit → dedup → block check → persist → FCM).
