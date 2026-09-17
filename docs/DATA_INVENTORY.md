# Personal data inventory

**Status:** Accepted (owner-signed checklist for store forms)  
**Date:** 2026-09-17  
**Related:** Z-PRV-001, Z-IOS-003  
**Owner:** Product / engineering — update this file whenever an SDK or data type is added.

Use this as the single source of truth when filling **App Store Privacy Nutrition Labels**, **Google Play Data safety**, and when editing `ios/Runner/PrivacyInfo.xcprivacy` or `docs/privacy-policy.md`.

## Collected data × purpose × destination

| Data type | Collected? | Linked to identity? | Used for tracking? | Purposes | Destinations / SDKs | Declared in PrivacyInfo | Declared in privacy policy |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Email address | Yes | Yes | No | Account, app functionality | Firebase Auth | Yes (`EmailAddress`) | Yes |
| Name / display name | Yes | Yes | No | App functionality | Firestore `users` | Yes (`Name`) | Yes |
| User ID | Yes | Yes | No | App functionality, analytics | Firebase Auth, Firestore, Analytics, Crashlytics | Yes (`UserID`) | Yes (account / usage) |
| Device ID / push token | Yes | Yes | No | App functionality, analytics | FCM, Analytics | Yes (`DeviceID`) | Yes |
| Session presence (online/away in a live room) | Yes (ephemeral) | Yes | No | App functionality | Firestore `sessions/{id}/presence/{uid}` — **session members only**; purged on expiry/leave | No (ephemeral operational) | Yes (session features) |
| Photos / images | Yes (optional) | Yes | No | App functionality | Firebase Storage (profile / posts); EXIF stripped client-side | Yes (`Photos`) | Yes |
| Audio data | Yes (optional voice notes) | Yes | No | App functionality | Firebase Storage | Yes (`AudioData`) | Yes |
| Product interaction / usage | Yes | Yes | No | Analytics (consent-gated) | Firebase Analytics (GA4) | Yes (`ProductInteraction`) | Yes |
| Crash data | Yes | Yes | No | App functionality / diagnostics | Firebase Crashlytics | Yes (`CrashData`) | Yes (usage / improve) |
| Workout / fitness logs | Yes | Yes | No | App functionality | Firestore (`sessions`, `workouts`, posts) | App Functionality (fitness content) — mirror on Play form as Health & fitness if asked | Yes |
| Social graph (follows, blocks, Facebook friend IDs on-app) | Yes | Yes | No | App functionality | Firestore; Facebook Login (optional) | Account / contacts as applicable on store forms | Yes |
| Payment info | No (payments feature flag off; no card numbers in app) | — | — | — | Stripe only if/when re-enabled | Do not declare until payments ship | Mentions Stripe as provider if/when enabled |
| Precise location | No | — | — | — | — | No | No |
| Contacts list (device address book) | No | — | — | — | — | No | No |

## Third-party SDKs in the mobile app

| SDK | Data it may process | Notes |
| --- | --- | --- |
| Firebase Auth | Email, user ID, auth tokens | Google / Apple / Facebook / email providers |
| Cloud Firestore | Profile, social, sessions, posts | Security rules + App Check |
| Firebase Storage | Photos, voice notes | EXIF strip on upload path |
| Firebase Analytics | Usage events | Gated by `PrivacyConsentService` |
| Firebase Crashlytics | Crash stacks, device/app metadata | Gated by consent where applicable |
| Firebase Messaging | FCM token, notification delivery | Push only |
| Firebase App Check | App attestation tokens | Abuse prevention |
| Google Sign-In | Auth identity | Optional |
| Sign in with Apple | Auth identity | Optional |
| Facebook Login (`flutter_facebook_auth`) | Auth identity; friends-on-app lookup | Meta data-deletion URL required — see `docs/data-deletion.md` |
| `image_picker` / `flutter_image_compress` | Photos on device | Local processing before upload |
| `record` / `audioplayers` | Microphone audio for voice notes | Local + Storage |
| `shared_preferences` | Local prefs (consent, caches) | PrivacyInfo UserDefaults reason CA92.1 |
| `in_app_review` | No personal payload | Store review prompt |
| `package_info_plus` | App version | Forced-update / diagnostics |

## Store form sync checklist

When changing the table above:

1. Update `ios/Runner/PrivacyInfo.xcprivacy` collected data types.
2. Update App Store Connect privacy answers.
3. Update Google Play Console Data safety form.
4. Update `docs/privacy-policy.md` if user-facing wording changes.
5. Keep Meta data-deletion URL live (`/legal/data-deletion`).

## Account deletion completeness (Z-PRV-005)

`cleanupDeletedUser` (Cloud Functions `onUserDeleted`) removes or detaches:

- User subcollections / devices / settings
- Workouts owned by the uid
- Posts authored or last remaining joint-author slots (+ Storage prefix)
- Profile photos Storage prefix
- Session participation via `detachUserFromSessions`

**Presence** is session-scoped only (not a global “last seen” flag). Docs under
`sessions/{id}/presence` are deleted when sessions expire and when members leave.

Facebook **App ID / Client Token** in Android/iOS resources are Meta client identifiers
(see `docs/CLIENT_SECRETS.md`) — not user access tokens.

## Verification

- Contract test asserts this inventory lists Firebase Analytics, Crashlytics, FCM, Auth email, photos, and audio, and that PrivacyInfo declares matching types.
