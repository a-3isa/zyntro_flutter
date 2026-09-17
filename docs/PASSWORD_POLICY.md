# Password policy

**Status:** Accepted  
**Date:** 2026-09-17  
**Related:** Z-AUTH-006

## Decision

Client signup trusts **Firebase Auth password policy** configured in the Firebase
Console (Authentication → Settings → Password policy). The app does not maintain a
parallel strength meter.

Current expected Firebase defaults for this project:

- Minimum length ≥ 6 (raise in Console if product requires stronger)
- Optional character-class requirements configured in Console only

## Consequences

1. Change length/complexity in Firebase Console — not in Dart.
2. Keep auth enumeration hardening (Z-AUTH-001) when surfacing password errors.
3. A strength meter is optional UX polish and must not diverge from Console rules.

## Verification

- This runbook exists; signup continues to use Firebase Auth `createUserWithEmailAndPassword`.
