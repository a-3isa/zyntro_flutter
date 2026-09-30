# Payments & digital entitlements

**Status:** Accepted  
**Date:** 2026-09-17  
**Related:** Z-PAY-001, Z-PAY-002, Z-ENH-021

## Decision

1. **Digital goods** (global leaderboard access and any future unlocks) ship through
   **platform billing only** — Google Play Billing and Apple StoreKit, preferably via
   RevenueCat (or equivalent) with a **server webhook** that writes entitlements via the
   Admin SDK.
2. **Stripe is not used for digital entitlements** on iOS/Android. Activating the mock
   PaymentIntent / client grant path would conflict with store policies (Z-PAY-002) and
   is already denied by Firestore rules (Z-PAY-001 / Z-DATA-001 privileged fields).
3. Stripe remains allowed only for **non-digital** use cases that stores permit
   (e.g. physical goods / services) if product later adds them — never for in-app unlocks.

## Current code posture

| Path | Status |
| --- | --- |
| `PaymentService.createGlobalLeaderboardPaymentIntent` | Mock only; must stay dark in production UI |
| `PaymentService.grantGlobalLeaderboardAccess` | Throws — clients cannot grant |
| `users.*.hasGlobalLeaderboardAccess` etc. | Admin/Functions write only |
| RevenueCat / IAP | Planned (`008-iap-entitlements` / ENH-021); not shipped |

## Consequences

1. Do not re-enable client Stripe PI or client entitlement writes.
2. Privacy policy / ToS should say “platform billing” for digital unlocks when IAP ships;
   keep Stripe mentions scoped to processors actually used.
3. Product copy must not promise paid global leaderboard until webhook entitlement is live.

## Verification

- Rules deny client writes to privileged entitlement fields.
- `grantGlobalLeaderboardAccess` throws on the client.
- This ADR is the policy answer for Z-PAY-001 / Z-PAY-002.
