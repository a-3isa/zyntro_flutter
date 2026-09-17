# Data Model: 008-firestore-trust-boundaries

## Entity: User profile (`users/{userId}`)

| Field | Type | Rules relevance |
|-------|------|-----------------|
| `isPrivate` | bool | **Required for discovery.** `false`/absent historically = public for `get`; list+search now require explicit `false` for inclusion in public queries. |
| `username` / `usernameLower` | string | Prefix search fields (existing). |
| Other profile fields | mixed | Readable on `get` when `canReadUserProfile`; not newly exposed via list. |
| Privileged fields | mixed | Unchanged denylist on create/update (out of scope). |

### Validation

- Create/update paths that establish a searchable profile MUST set `isPrivate` to a boolean (default `false`).
- Flipping `isPrivate` to `true` immediately excludes the doc from public list queries under the new rules.

## Entity: Username claim (`usernames/{username}`)

| Field | Type | Notes |
|-------|------|-------|
| `uid` | string | Maps handle → userId only. MUST NOT store private profile blobs. |

Unchanged ACL: get for auth users; list false; create claim; no update/delete by clients.

## Entity: Follow (`follows/{id}`)

Used by `isApprovedFollowerOf` for **get** paths only in this design. No list dependency on follows for stranger discovery.

## Indexes

Existing username prefix queries may need a composite if combined with `isPrivate`:

- Collection: `users`
- Fields: `isPrivate` ASC, `usernameLower` ASC (and/or range pair as required by the final query)

Add to `firebase/firestore.indexes.json` only if the emulator/client reports a missing-index error.

## State transitions

```text
isPrivate false → true : drops out of public search/list immediately (rules + query)
isPrivate true  → false : becomes listable/searchable again when boolean is false
```
