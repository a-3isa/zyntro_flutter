# Client config & key rotation

**Status:** Accepted  
**Date:** 2026-09-17  
**Related:** Z-SEC-009, Z-AND-004

## What lived in git history

Historical commits may contain **publishable** client config (Firebase web API keys,
Stripe publishable keys, Facebook App ID / client token). These are not server secrets,
but they should still be **restricted** and rotated if exposure is concerning.

## Required posture

| Asset | Treatment |
| --- | --- |
| Firebase Android/iOS API keys | Restrict by app package / SHA / bundle ID in Google Cloud Console |
| Firebase web API key | HTTP referrer restrictions; never grant Admin |
| Stripe **publishable** key | Allowed in client; rotate if leaked with secret |
| Stripe **secret** | Never in client; Functions-only |
| Facebook App ID / Client Token | Public client IDs; keep out of marketing screenshots; rotate via Meta dashboard if abused |
| `.env` / `google-services.json` / `GoogleService-Info.plist` | Gitignored locally; CI injects from secrets |

## Rotation checklist

1. Rotate compromised keys in the provider console.
2. Update CI secrets / Codemagic env / local `.env` (never commit).
3. Redeploy Functions if server keys changed.
4. **Do not** rewrite git history unless Legal/SecOps requires it — prefer restrict + rotate.

## Android Facebook strings (Z-AND-004)

`android/app/src/main/res/values/strings.xml` holds the Facebook App ID because the SDK
requires manifest meta-data. Treat as public client config; prefer flavor/`local.properties`
injection for white-label forks. App Check debug channel stays under `src/debug/` only.

## Verification

- `.env` is gitignored (see `.gitignore`).
- This runbook is linked from audit closure for Z-SEC-009.
