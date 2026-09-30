# Research: 008-firestore-trust-boundaries

## Decision: Constrain `users` list with resource-based public check (not blanket auth)

**Rationale**: Firestore fails an entire query if any matching document could violate rules. Setting `allow list` to full `canReadUserProfile(userId)` (with `isApprovedFollowerOf` → `get()`) is expensive and makes follower-aware list queries impractical. For discovery we only need **public** profiles in list results; private reads stay on `get` (already correct).

**Chosen rule shape** (conceptual):

```
allow list: if isAuthenticated() && (
  isOwner(userId) ||
  isModerator() ||
  resource.data.get('isPrivate', false) != true
);
```

**Client search** MUST add `.where('isPrivate', isEqualTo: false)` (and keep username prefix bounds) so the query is guaranteed to only request public docs.

## Decision: Defer dedicated `publicProfiles` projection collection

**Rationale**: Equality filter + list rule closes Z-SEC-001 with minimal moving parts. A synced projection adds CF write paths, backfill, and drift risk.

**Alternatives considered**:
| Option | Pros | Cons |
|--------|------|------|
| A. List = `canReadUserProfile` | Perfect ACL parity | Query+follower get() limits; public search often fails entirely |
| B. Public projection collection | Clean list surface | CF sync, backfill, two sources of truth |
| **C. Resource public check + client filter (chosen)** | Small diff, emulator-provable | Docs missing `isPrivate` need defaulting; followers don't list private peers (use get) |

## Decision: Ensure `isPrivate` is always a boolean on write paths used by search

**Rationale**: `isPublicProfile` today treats missing as public (`!= true`). Client filter `isPrivate == false` **excludes** missing fields. Profile create/update and any migration note must set `isPrivate: false` by default so public users remain discoverable.

## Decision: Emulator tests in `test/rules/` before deploy

**Rationale**: Spec SC-001/SC-005; prior audit required regression guards for security fixes. Reuse `@firebase/rules-unit-testing` patterns from `social.rules.test.mjs`.

## Decision: No change to privileged field denylists in this slice

**Rationale**: Spec FR-006 / out-of-scope Z-DATA-001 → `008-server-scores`.

## Resolved clarifications

| Topic | Resolution |
|-------|------------|
| How do approved followers see private Alice in search? | They don't via list; product uses known uid / follow graph + `get`. |
| Username collection backdoor? | Keep `usernames` mapping uid-only; no private profile payload on that doc. |
| Leaderboard listing users? | Out of scope unless a call site breaks; if a `users` query lacks `isPrivate` filter, fix that call site in this slice when tests fail. |
